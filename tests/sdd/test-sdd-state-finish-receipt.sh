#!/usr/bin/env bash
# Behavior tests for the receipt finish leaves behind: the durable copy of
# the workspace it removes, published in two phases (a dot-prefixed staging
# built before anything is removed, renamed into place only after the
# removal and its commit succeed), and the prune that reclaims old ones.
# Everything runs under a temporary cache root and never touches the real
# ~/.cache. No pipefail: several checks pipe a producer into grep -q, and
# under pipefail the producer's SIGPIPE would read as a failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_DIR="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-dir"
SDD_STATE="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-state"

failures=0
TEST_ROOT=$(mktemp -d) || exit 2
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || exit 2
# git prints worktree paths physically; a symlinked temp root (macOS /var)
# would make the receipt paths disagree with the workspace paths.
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 2
export XDG_CACHE_HOME="$TEST_ROOT/cache"
# As in the sibling suite: a host-global hyperpowers.stateBranch, or a
# clone.defaultRemoteName other than origin, would fail this suite there and
# nowhere else (GIT_CONFIG_GLOBAL needs git 2.32+).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
cleanup() { if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then chmod 700 "$XDG_CACHE_HOME/hyperpowers/receipts" 2>/dev/null; rm -rf "$TEST_ROOT"; fi; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

make_repo() { # <path>
    git init -q -b main "$1"
    git -C "$1" config user.name "Test Bot"
    git -C "$1" config user.email "test@example.com"
    git -C "$1" commit -q --allow-empty -m "initial"
}
run_state() { ( cd "$1" && shift && bash "$SDD_STATE" "$@" ); }
run_sdd_dir() { ( cd "$1" && shift && bash "$SDD_DIR" "$@" ); }

repo="$TEST_ROOT/r"; make_repo "$repo"
mkdir -p "$repo/docs"; printf '# Plan\n\n### Task 1: one\n' > "$repo/docs/plan.md"
git -C "$repo" add docs/plan.md; git -C "$repo" commit -qm plan
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s1: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"

RECEIPTS="$XDG_CACHE_HOME/hyperpowers/receipts"
echo "=== finish writes a receipt ==="
out=$(run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
# The marker goes in before the rename (it says the removal and its commit
# are done), so a renamed receipt carries it beside the ledger.
if [ "$rc" -eq 0 ] && [ -n "$r" ] && [ -f "$r/progress.md" ] && [ -f "$r/FINISHED" ] && [ "$(find "$r" -mindepth 1 | wc -l | tr -d ' ')" = 2 ] && [ ! -d "$ws" ]; then pass "a finish with no hook log and no jobs writes a receipt with the ledger alone"; else fail "a finish with no hook log and no jobs writes a receipt with the ledger alone (rc=$rc: $out)"; fi
case "$(basename "$r")" in .staging-*) fail "the receipt is renamed out of staging" ;; *) pass "the receipt is renamed out of staging" ;; esac
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s2: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
printf '{"ts":"2026-10-23T00:00:01.000Z","session":"s2","decision":"block","reason":"open-tasks"}\n' > "$ws/stop-guard.jsonl"
mkdir -p "$ws/jobs/a-x-0001" "$ws/jobs/b-x-0002" "$ws/jobs/c-x-0003"
printf '{"name":"a","state":"allocated"}\n' > "$ws/jobs/a-x-0001/meta.json"
printf '{"name":"b","state":"lost"}\n' > "$ws/jobs/b-x-0002/meta.json"; printf 'noise\n' > "$ws/jobs/b-x-0002/out.log"
printf '{"name":"c","state":"exited"}\n' > "$ws/jobs/c-x-0003/meta.json"; printf '0\n' > "$ws/jobs/c-x-0003/exit"; printf 'noise\n' > "$ws/jobs/c-x-0003/out.log"
# a job that never got its metadata, and a write-failure record beside the ledger: neither is copied, neither stops the finish
mkdir -p "$ws/jobs/d-x-0004"; printf 'noise\n' > "$ws/jobs/d-x-0004/out.log"
printf '2026-10-23T00:00:00Z handback s2 2026-10-23T00:00:0\n' > "$ws/fragments.log"
out=$(run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ -f "$r/stop-guard.jsonl" ] && [ -f "$r/jobs/a-x-0001/meta.json" ] && [ -f "$r/jobs/b-x-0002/meta.json" ] && [ ! -e "$r/jobs/b-x-0002/exit" ] && [ -f "$r/jobs/c-x-0003/exit" ] && [ ! -e "$r/jobs/b-x-0002/out.log" ] && [ ! -e "$r/jobs/d-x-0004" ] && [ ! -e "$r/fragments.log" ]; then pass "the receipt copies the hook log, every meta.json and the exit files that exist, and nothing else"; else fail "the receipt copies the hook log, every meta.json and the exit files that exist, and nothing else (rc=$rc: $out)"; fi
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s3: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
chmod 500 "$RECEIPTS"
out=$(run_state "$repo" finish docs/plan.md); rc=$?
chmod 700 "$RECEIPTS"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$ws/progress.md" ]; then pass "a receipt that cannot be staged stops finish with the workspace intact"; else fail "a receipt that cannot be staged stops finish with the workspace intact (rc=$rc: $out)"; fi
# a failure after staging (the removal refused) removes the staging and leaves no receipt.
out=$(HYPERPOWERS_TEST_FAIL_REMOVE=1 run_state "$repo" finish docs/plan.md); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$ws/progress.md" ] && ! ls -d "$RECEIPTS"/.staging-* >/dev/null 2>&1 && [ "$(find "$RECEIPTS" -maxdepth 1 -mindepth 1 ! -name '.*' | wc -l | tr -d ' ')" = 2 ]; then pass "a finish that fails after staging removes the staging and writes no receipt"; else fail "a finish that fails after staging removes the staging and writes no receipt (rc=$rc: $out)"; fi
# a rename that fails after the removal: the record stays as a FINISHED staging and finish still succeeds.
out=$(HYPERPOWERS_TEST_FAIL_RENAME=1 run_state "$repo" finish docs/plan.md); rc=$?
r=$(printf '%s' "$out" | sed -n 's/.*receipt=\([^ ]*\).*/\1/p')
case "$(basename "$r")" in .staging-*) staged=1 ;; *) staged=0 ;; esac
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=finished' && [ "$staged" = 1 ] && [ -f "$r/FINISHED" ] && [ -f "$r/progress.md" ] && [ ! -d "$ws" ]; then pass "a rename that fails after the removal leaves a FINISHED staging as the receipt"; else fail "a rename that fails after the removal leaves a FINISHED staging as the receipt (rc=$rc: $out)"; fi
# neither the rename nor the marker: finish still succeeds and says receipt=none with the staging path.
ws=$(run_sdd_dir "$repo" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\nsession s4: mode worktree on main at %s started 2026-10-23T00:00:00Z\n' "$repo" > "$ws/progress.md"
out=$(HYPERPOWERS_TEST_FAIL_RENAME=1 HYPERPOWERS_TEST_FAIL_MARKER=1 run_state "$repo" finish docs/plan.md); rc=$?
st=$(printf '%s' "$out" | sed -n 's/.*staging=\([^ ]*\).*/\1/p')
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^status=finished' && printf '%s' "$out" | grep -q ' receipt=none staging=' && [ -f "$st/progress.md" ] && [ ! -e "$st/FINISHED" ] && [ ! -d "$ws" ]; then pass "a staging that can be neither renamed nor marked is reported as receipt=none with its path"; else fail "a staging that can be neither renamed nor marked is reported as receipt=none with its path (rc=$rc: $out)"; fi
# a finished receipt keeps its marker harmlessly, and the hook and analyzer accept it by name alone (Tasks 6 and 14).
old="$RECEIPTS/old-ws-20200101T000000Z"; mkdir -p "$old"; printf 'x\n' > "$old/progress.md"; touch -t 202001010000 "$old" "$old/progress.md"
stale="$RECEIPTS/.staging-old2-20200101T000000Z"; mkdir -p "$stale"; touch -t 202001010000 "$stale"
finished="$RECEIPTS/.staging-old3-20200101T000000Z"; mkdir -p "$finished"; printf 'x\n' > "$finished/progress.md"; : > "$finished/FINISHED"; touch -t 202001010000 "$finished" "$finished/progress.md" "$finished/FINISHED"
out=$(run_state "$repo" prune --receipts --days 30); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "old-ws-20200101T000000Z" && printf '%s' "$out" | grep -q ".staging-old2.*stale=1" && printf '%s' "$out" | grep -q ".staging-old3" && ! printf '%s' "$out" | grep -q ".staging-old3.*stale=1" && [ -d "$old" ] && printf '%s' "$out" | grep -q '^status=listed receipts=3$'; then pass "prune --receipts lists old receipts, marks stale stagings, and leaves everything without --apply"; else fail "prune --receipts lists old receipts, marks stale stagings, and leaves everything without --apply (rc=$rc: $out)"; fi
out=$(run_state "$repo" prune --receipts --days 30 --apply); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$old" ] && [ ! -d "$stale" ] && [ ! -d "$finished" ] && [ "$(find "$RECEIPTS" -maxdepth 1 -mindepth 1 ! -name '.*' | wc -l | tr -d ' ')" = 2 ] && [ "$(find "$RECEIPTS" -maxdepth 1 -mindepth 1 -name '.staging-*' | wc -l | tr -d ' ')" = 2 ] && printf '%s' "$out" | grep -q '^status=pruned receipts=3$'; then pass "prune --receipts --apply removes only the old ones and keeps the two young stagings"; else fail "prune --receipts --apply removes only the old ones and keeps the two young stagings (rc=$rc: $out)"; fi
out=$(run_state "$repo" prune --receipts --days 30); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=listed receipts=0" ]; then pass "a receipt younger than --days is left out of the listing"; else fail "a receipt younger than --days is left out of the listing (rc=$rc: $out)"; fi
out=$(run_state "$repo" prune --receipts --repo "$repo" 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "prune refuses --receipts together with --repo"; else fail "prune refuses --receipts together with --repo (rc=$rc: $out)"; fi

if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
