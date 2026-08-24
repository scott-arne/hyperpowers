#!/usr/bin/env bash
# Regression check for the Codex review-gate scratch-dir derivation.
#
# The gate's scratch files (prompt files, round ledger, handoffs) used to be
# documented at a flat, unkeyed path
# (${XDG_CACHE_HOME}/hyperpowers/codex-review/codex-round-ledger.md). Any two
# concurrent hyperpowers sessions — even in different repos — wrote the same
# ledger and the same prompt files, so one gate could clobber another's
# scratch or send Codex the wrong document. scripts/codex-review-dir gives
# each gate invocation its own fresh dir. This test locks in the properties
# that fix must preserve — most importantly, that two invocations NEVER share
# a dir, including two runs in the same repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REVIEW_DIR_SCRIPT="$REPO_ROOT/skills/requesting-code-review/scripts/codex-review-dir"

failures=0
TEST_ROOT="$(mktemp -d)"
# Pin the cache root into the sandbox so a run never touches the real
# ~/.cache, and so we can assert on where output lands.
export XDG_CACHE_HOME="$TEST_ROOT/cache"

cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT
# The gate is an index plus section-file siblings; grep the union, not the
# index — otherwise a split would make these greps pressure content back
# into the index just to keep them passing.
GATE="$TEST_ROOT/assembled-gate.md"
bash "$REPO_ROOT/tests/codex-review-gate/assemble-gate.sh" "$REPO_ROOT" "$GATE"

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

run_review_dir() { ( cd "$1" && bash "$REVIEW_DIR_SCRIPT" ); }

echo "=== Codex review-gate scratch-dir path test ==="
echo ""

repo_a="$TEST_ROOT/repo-a"
repo_b="$TEST_ROOT/repo-b"
make_repo "$repo_a"
make_repo "$repo_b"

dir_a1="$(run_review_dir "$repo_a")"
dir_a2="$(run_review_dir "$repo_a")"
dir_b1="$(run_review_dir "$repo_b")"

# 1. Never under a protected path.
case "$dir_a1" in
    */.git/*) fail "scratch dir is not under .git/ (got: $dir_a1)" ;;
    *) pass "scratch dir is not under .git/" ;;
esac

# 2. Never inside the repo working tree (can't be accidentally committed).
case "$dir_a1" in
    "$repo_a"/*) fail "scratch dir is outside the working tree (got: $dir_a1)" ;;
    *) pass "scratch dir is outside the working tree" ;;
esac

# 3. Lands under the configured user cache.
case "$dir_a1" in
    "$XDG_CACHE_HOME"/hyperpowers/codex-review/*) pass "scratch dir is under \$XDG_CACHE_HOME/hyperpowers/codex-review" ;;
    *) fail "scratch dir is under \$XDG_CACHE_HOME/hyperpowers/codex-review (got: $dir_a1)" ;;
esac

# 4. THE KEY PROPERTY: fresh per invocation, even in the same repo. Two gates
#    running concurrently in one worktree must not share a ledger.
if [ "$dir_a1" != "$dir_a2" ]; then
    pass "scratch dir is unique per invocation in the same repo"
else
    fail "scratch dir is unique per invocation in the same repo (both: $dir_a1)"
fi

# 5. Distinct across repos too (concurrent sessions in different repos).
if [ "$dir_a1" != "$dir_b1" ]; then
    pass "scratch dir differs across distinct repos"
else
    fail "scratch dir differs across distinct repos (both: $dir_a1)"
fi

# 6. The helper creates the directory it prints.
if [ -d "$dir_a1" ]; then
    pass "helper creates the scratch directory"
else
    fail "helper creates the scratch directory (missing: $dir_a1)"
fi

# 7. Outside a git repo it fails loudly rather than emitting a bogus path.
if ( cd "$TEST_ROOT" && bash "$REVIEW_DIR_SCRIPT" ) >/dev/null 2>&1; then
    fail "helper fails outside a git repository"
else
    pass "helper fails outside a git repository"
fi

# 8. The gate doc routes scratch through the helper, not a flat/hand-written
#    path. A literal codex-round-ledger.md under a bare codex-review/ dir was
#    the clobber-prone form; it must be gone.
if grep -Fq 'scripts/codex-review-dir' "$GATE"; then
    pass "gate doc invokes the codex-review-dir helper"
else
    fail "gate doc invokes the codex-review-dir helper"
fi
if grep -Fq 'hyperpowers/codex-review/codex-round-ledger.md' "$GATE"; then
    fail "gate doc no longer names the flat, shared ledger path"
else
    pass "gate doc no longer names the flat, shared ledger path"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
