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

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
