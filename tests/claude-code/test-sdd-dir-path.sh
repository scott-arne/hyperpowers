#!/usr/bin/env bash
# Regression check for the SDD scratch-dir derivation.
#
# The scratch dir used to be <git-dir>/sdd (via `git rev-parse --git-path
# sdd`). Because .git/ is a hardcoded protected path in Claude Code, writes
# there prompt in every mode except bypassPermissions, and that check runs
# before permission rules and PreToolUse hooks — so nothing could suppress
# it. scripts/sdd-dir relocates the scratch dir off .git/ into the user
# cache. This test locks in the properties that relocation must preserve.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SDD_DIR_SCRIPT="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-dir"
TASK_BRIEF="$REPO_ROOT/skills/subagent-driven-development/scripts/task-brief"
REVIEW_PACKAGE="$REPO_ROOT/skills/subagent-driven-development/scripts/review-package"

failures=0
TEST_ROOT="$(mktemp -d)"
# Pin the cache root into the sandbox so a run never touches the real
# ~/.cache, and so we can assert on where output lands.
export XDG_CACHE_HOME="$TEST_ROOT/cache"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

make_repo() {
    local repo="$1"
    git init -q -b main "$repo"
    git -C "$repo" config user.name "Test Bot"
    git -C "$repo" config user.email "test@example.com"
}

run_sdd_dir() { ( cd "$1" && bash "$SDD_DIR_SCRIPT" ); }

echo "=== SDD scratch-dir path test ==="
echo ""

repo_a="$TEST_ROOT/repo-a"
repo_b="$TEST_ROOT/repo-b"
make_repo "$repo_a"
make_repo "$repo_b"

dir_a="$(run_sdd_dir "$repo_a")"
dir_a2="$(run_sdd_dir "$repo_a")"
dir_b="$(run_sdd_dir "$repo_b")"

# 1. Never under a protected path.
case "$dir_a" in
    */.git/*) fail "scratch dir is not under .git/ (got: $dir_a)" ;;
    *) pass "scratch dir is not under .git/" ;;
esac

# 2. Never inside the repo working tree (can't be accidentally committed).
case "$dir_a" in
    "$repo_a"/*) fail "scratch dir is outside the working tree (got: $dir_a)" ;;
    *) pass "scratch dir is outside the working tree" ;;
esac

# 3. Lands under the configured user cache.
case "$dir_a" in
    "$XDG_CACHE_HOME"/hyperpowers/sdd/*) pass "scratch dir is under \$XDG_CACHE_HOME/hyperpowers/sdd" ;;
    *) fail "scratch dir is under \$XDG_CACHE_HOME/hyperpowers/sdd (got: $dir_a)" ;;
esac

# 4. Stable across invocations in the same repo (resume must find the ledger).
if [ "$dir_a" = "$dir_a2" ]; then
    pass "scratch dir is stable across invocations in the same repo"
else
    fail "scratch dir is stable across invocations ($dir_a vs $dir_a2)"
fi

# 5. Distinct across repos (concurrent sessions must not collide).
if [ "$dir_a" != "$dir_b" ]; then
    pass "scratch dir differs across distinct repos"
else
    fail "scratch dir differs across distinct repos (both: $dir_a)"
fi

# 6. The helper creates the directory it prints.
if [ -d "$dir_a" ]; then
    pass "helper creates the scratch directory"
else
    fail "helper creates the scratch directory (missing: $dir_a)"
fi

# 7. Outside a git repo it fails loudly rather than emitting a bogus path.
if ( cd "$TEST_ROOT" && bash "$SDD_DIR_SCRIPT" ) >/dev/null 2>&1; then
    fail "helper fails outside a git repository"
else
    pass "helper fails outside a git repository"
fi

# 8. The callers route their default path through the helper, not .git/ directly.
if grep -Fq 'git rev-parse --git-path sdd' "$TASK_BRIEF" "$REVIEW_PACKAGE"; then
    fail "task-brief/review-package no longer derive the default path from .git/"
else
    pass "task-brief/review-package no longer derive the default path from .git/"
fi
if grep -Fq 'sdd-dir' "$TASK_BRIEF" && grep -Fq 'sdd-dir' "$REVIEW_PACKAGE"; then
    pass "task-brief/review-package both call the sdd-dir helper"
else
    fail "task-brief/review-package both call the sdd-dir helper"
fi

# 9. The explicit OUTFILE override still wins over the helper default.
override="$TEST_ROOT/custom-brief.md"
cat > "$repo_a/plan.md" <<'EOF'
## Task 1: Example

Do the thing.
EOF
( cd "$repo_a" && bash "$TASK_BRIEF" plan.md 1 "$override" ) >/dev/null
if [ -f "$override" ]; then
    pass "task-brief honors an explicit OUTFILE override"
else
    fail "task-brief honors an explicit OUTFILE override"
fi

# 10. review-package honors an explicit OUTFILE override.
override_review="$TEST_ROOT/custom-review.diff"
git -C "$repo_a" commit --allow-empty -m "initial commit" >/dev/null
git -C "$repo_a" commit --allow-empty -m "second commit" >/dev/null
( cd "$repo_a" && bash "$REVIEW_PACKAGE" plan.md HEAD~1 HEAD "$override_review" ) >/dev/null
if [ -f "$override_review" ]; then
    pass "review-package honors an explicit OUTFILE override"
else
    fail "review-package honors an explicit OUTFILE override"
fi

# 11. Stale sibling scratch dirs (idle past the 14-day threshold) are
# reclaimed on invocation; fresh siblings survive.
sdd_base="$XDG_CACHE_HOME/hyperpowers/sdd"
stale_dir="$sdd_base/stale-run"
fresh_dir="$sdd_base/fresh-run"
mkdir -p "$stale_dir" "$fresh_dir"
touch "$stale_dir/task-1-brief.md"
# Backdate after populating: adding the file bumps the dir mtime.
touch -t 202601010000 "$stale_dir"
run_sdd_dir "$repo_a" >/dev/null
if [ ! -d "$stale_dir" ]; then
    pass "stale sibling scratch dir is pruned"
else
    fail "stale sibling scratch dir is pruned (still present: $stale_dir)"
fi
if [ -d "$fresh_dir" ]; then
    pass "fresh sibling scratch dir survives pruning"
else
    fail "fresh sibling scratch dir survives pruning (missing: $fresh_dir)"
fi

# 12. The current repo's dir is never pruned, even when idle past the
# threshold — a resumed session must find its ledger.
touch -t 202601010000 "$dir_a"
dir_a3="$(run_sdd_dir "$repo_a")"
if [ -d "$dir_a" ] && [ "$dir_a3" = "$dir_a" ]; then
    pass "current repo's dir survives pruning when idle"
else
    fail "current repo's dir survives pruning when idle (missing or moved: $dir_a)"
fi

echo "Test: plan-scoped workspaces are distinct for same-basename plans"
make_repo "$TEST_ROOT/repo-plan"
mkdir -p "$TEST_ROOT/repo-plan/docs/a" "$TEST_ROOT/repo-plan/docs/b"
echo plan > "$TEST_ROOT/repo-plan/docs/a/plan.md"
echo plan > "$TEST_ROOT/repo-plan/docs/b/plan.md"
noarg=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT")
da=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
db=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
if [ "$da" != "$db" ]; then pass "same basename, different dirs -> distinct workspaces"; else fail "collision: $da == $db"; fi
case "$da" in "$noarg"/plans/plan-*) pass "plan dir nests under repo plans/ subdir with slug prefix";; *) fail "unexpected plan dir shape: $da (repo dir: $noarg)";; esac
dabs=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$da" = "$dabs" ]; then pass "relative and absolute plan paths agree"; else fail "path-form sensitivity: $da vs $dabs"; fi

echo "Test: stale sibling plan workspaces pruned; fresh and non-plan content kept"
stale="$noarg/plans/old-plan-deadbeef"
freshdir="$noarg/plans/fresh-plan-cafef00d"
nonplan="$noarg/perf-cache-notaplan"
mkdir -p "$stale" "$freshdir" "$nonplan"
OLDSTAMP="$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)"
touch -mt "$OLDSTAMP" "$stale" "$nonplan"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ ! -d "$stale" ]; then pass "stale sibling plan dir pruned"; else fail "stale plan dir survived"; fi
if [ -d "$freshdir" ]; then pass "fresh sibling plan dir kept"; else fail "fresh plan dir wrongly pruned"; fi
if [ -d "$nonplan" ]; then pass "stale NON-plan sibling under repo root preserved"; else fail "GC deleted non-plan cache content"; fi

echo "Test: resumed plan workspace survives sibling GC"
planA_dir=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
mkdir -p "$planA_dir"
touch -mt "$OLDSTAMP" "$planA_dir"
_resume=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ "$(find "$planA_dir" -maxdepth 0 -mtime +14 | wc -l)" -eq 0 ]; then pass "resume refreshes plan dir mtime"; else fail "plan dir still stale after resume"; fi
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
if [ -d "$planA_dir" ]; then pass "resumed plan A survives plan B's invocation"; else fail "plan A wrongly pruned by plan B GC"; fi

echo "Test: plan mode refreshes parent repo cache dir to survive cross-repo GC"
planA_dir=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
repo_plan_cache="$noarg"
mkdir -p "$planA_dir"
touch -mt "$OLDSTAMP" "$planA_dir" "$repo_plan_cache"
_resume=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ "$(find "$repo_plan_cache" -maxdepth 0 -mtime +14 | wc -l)" -eq 0 ]; then pass "resume refreshes parent repo cache dir mtime"; else fail "parent repo cache dir still stale after plan resume"; fi
make_repo "$TEST_ROOT/repo-gc-other"
_other=$(cd "$TEST_ROOT/repo-gc-other" && "$SDD_DIR_SCRIPT")
if [ -d "$repo_plan_cache" ]; then pass "active plan's parent repo cache dir survives cross-repo GC"; else fail "parent repo cache dir wrongly pruned by another repo's GC"; fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
