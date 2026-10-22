#!/usr/bin/env bash
# Regression check for skills/writing-plans/scripts/docs-allowlist.
#
# The planning directory used to be gitignored wholesale, so anything an
# agent dropped there stayed local. Now that specs and plans are committed,
# the directory needs an allowlist: only specs/ and plans/ may reach the
# index, an existing ignore file is never rewritten, and an outer rule that
# ignores the whole directory is reported rather than silently defeated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALLOWLIST="$REPO_ROOT/skills/writing-plans/scripts/docs-allowlist"

failures=0
# Physical path: the script reports physical paths, and macOS puts mktemp
# output behind a symlink.
TEST_ROOT=$(mktemp -d) || { echo "mktemp failed" >&2; exit 1; }
[ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ] || { echo "no temporary directory" >&2; exit 1; }
TEST_ROOT=$(cd "$TEST_ROOT" && pwd -P) || exit 1
case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) echo "refusing temporary root $TEST_ROOT" >&2; exit 1 ;; esac
cleanup() { case "$TEST_ROOT" in ""|/|"$REPO_ROOT"|"$REPO_ROOT"/*) return ;; esac; rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; failures=$((failures + 1)); }

make_repo() {
    git init -q "$1"
    git -C "$1" config user.email test@example.com
    git -C "$1" config user.name test
}

# Index-free ignore check, so the paths need not exist.
ignored() { git -C "$1" check-ignore -q --no-index -- "$2"; }

echo "=== docs-allowlist ==="

repo="$TEST_ROOT/default"
make_repo "$repo"
target="$repo/docs/hyperpowers/.gitignore"
out=$(cd "$repo" && bash "$ALLOWLIST")
if [ "$out" = "wrote $target" ]; then
    pass "first run prints 'wrote <path>' and nothing else"
else
    fail "first run stdout (got: $out)"
fi
if [ -f "$target" ]; then
    pass "writes docs/hyperpowers/.gitignore under the repository root"
else
    fail "no .gitignore at $target"
fi

for p in docs/hyperpowers/specs/a.md docs/hyperpowers/plans/b.md \
         docs/hyperpowers/plans/nested/c.md docs/hyperpowers/decisions/d.md \
         docs/hyperpowers/decisions/README.md docs/hyperpowers/.gitignore; do
    if ignored "$repo" "$p"; then fail "$p is ignored"; else pass "$p is not ignored"; fi
done
for p in docs/hyperpowers/evidence/run.log docs/hyperpowers/notes.md \
         docs/hyperpowers/codex-gate/task-1/report.md; do
    if ignored "$repo" "$p"; then pass "$p is ignored"; else fail "$p is not ignored"; fi
done

# End to end: a blanket add stages only the allowed paths.
mkdir -p "$repo/docs/hyperpowers/specs" "$repo/docs/hyperpowers/plans" "$repo/docs/hyperpowers/decisions" "$repo/docs/hyperpowers/evidence"
echo s > "$repo/docs/hyperpowers/specs/a.md"
echo p > "$repo/docs/hyperpowers/plans/b.md"
echo d > "$repo/docs/hyperpowers/decisions/d.md"
echo e > "$repo/docs/hyperpowers/evidence/run.log"
echo n > "$repo/docs/hyperpowers/notes.md"
git -C "$repo" add -A
staged=$(git -C "$repo" diff --cached --name-only | sort | tr '\n' ' ')
expected="docs/hyperpowers/.gitignore docs/hyperpowers/decisions/d.md docs/hyperpowers/plans/b.md docs/hyperpowers/specs/a.md "
if [ "$staged" = "$expected" ]; then
    pass "git add -A stages only the ignore file, specs/, plans/ and decisions/"
else
    fail "staged set (got: $staged)"
fi

# An existing file is reported and left alone, edits included.
echo '!/sentinel/' >> "$target"
out=$(cd "$repo" && bash "$ALLOWLIST")
if [ "$out" = "exists $target" ]; then
    pass "second run prints 'exists <path>'"
else
    fail "second run stdout (got: $out)"
fi
if grep -q '^!/sentinel/$' "$target"; then
    pass "an existing .gitignore is left untouched"
else
    fail "existing .gitignore was rewritten"
fi

# An explicit directory, given relative to the cwd, is reported physically.
out=$(cd "$repo" && bash "$ALLOWLIST" docs/planning)
if [ "$out" = "wrote $repo/docs/planning/.gitignore" ] && [ -f "$repo/docs/planning/.gitignore" ]; then
    pass "DIR argument is honoured"
else
    fail "DIR argument (got: $out)"
fi

# An outer rule that ignores the directory is reported, not lifted.
repo2="$TEST_ROOT/outer"
make_repo "$repo2"
printf 'docs/hyperpowers/\n' > "$repo2/.gitignore"
out=$(cd "$repo2" && bash "$ALLOWLIST")
first=$(printf '%s\n' "$out" | sed -n 1p)
second=$(printf '%s\n' "$out" | sed -n 2p)
case "$first" in
    "wrote "*) pass "outer rule: the allowlist is still written" ;;
    *) fail "outer rule: first line (got: $first)" ;;
esac
if [ "$second" = "ignored-by .gitignore:1:docs/hyperpowers/" ]; then
    pass "outer rule is reported as 'ignored-by <source>:<line>:<pattern>'"
else
    fail "outer rule report (got: $second)"
fi
if [ "$(wc -l < "$repo2/.gitignore" | tr -d ' ')" = "1" ]; then
    pass "outer .gitignore is left for its owner to lift"
else
    fail "outer .gitignore was modified"
fi
out=$(cd "$repo" && bash "$ALLOWLIST")
if [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "1" ]; then
    pass "no 'ignored-by' line when the directory is not ignored"
else
    fail "unexpected extra output (got: $out)"
fi

if (cd "$repo" && bash "$ALLOWLIST" a b 2>/dev/null); then
    fail "two arguments were accepted"
else
    pass "two arguments are a usage error"
fi

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
