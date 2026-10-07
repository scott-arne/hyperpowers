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

# 10a. review-package uses default path through sdd-dir when OUTFILE omitted.
default_review_output=$(cd "$repo_a" && bash "$REVIEW_PACKAGE" plan.md HEAD~1 HEAD 2>&1)
expected_sdd_dir=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT" plan.md)
base_short=$(git -C "$repo_a" rev-parse --short HEAD~1)
head_short=$(git -C "$repo_a" rev-parse --short HEAD)
expected_path="$expected_sdd_dir/review-${base_short}..${head_short}.diff"
if grep -q "$expected_path" <<< "$default_review_output" && [ -f "$expected_path" ]; then
    pass "review-package uses default path through sdd-dir when OUTFILE omitted"
else
    fail "review-package uses default path through sdd-dir (expected: $expected_path)"
fi

# 10b. review-package rejects nonexistent plan file.
if ( cd "$repo_a" && bash "$REVIEW_PACKAGE" nonexistent.md HEAD~1 HEAD ) >/dev/null 2>&1; then
    fail "review-package rejects nonexistent plan file"
else
    pass "review-package rejects nonexistent plan file"
    # Verify it didn't create a workspace for the bad path.
    # Derive the expected path WITHOUT calling sdd-dir (which would create it).
    repo_key=$(printf '%s' "$(git -C "$repo_a" rev-parse --absolute-git-dir)" | git hash-object --stdin)
    rel_path="nonexistent.md"
    hash8=$(printf '%s' "$rel_path" | git hash-object --stdin | cut -c1-8)
    slug="nonexistent"
    expected_nonexistent_dir="$XDG_CACHE_HOME/hyperpowers/sdd/$repo_key/plans/$slug-$hash8"
    if [ -d "$expected_nonexistent_dir" ]; then
        fail "review-package should not create workspace for nonexistent plan (found: $expected_nonexistent_dir)"
    else
        pass "review-package did not create workspace for nonexistent plan"
    fi
fi

# 10c. A plan is keyed by its own repository, whatever the cwd. A cross-repo
# plan used to get one workspace per repository it was invoked from.
from_a=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT" plan.md)
from_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan.md")
if [ "$from_a" = "$from_b" ]; then
    pass "sdd-dir keys a plan by the plan's repository, not the cwd"
else
    fail "sdd-dir keys a plan by the plan's repository, not the cwd (from A: $from_a, from B: $from_b)"
fi

# 10d. Without a plan argument the cwd still keys, and the two repos differ.
bare_a=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT")
bare_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT")
if [ "$bare_a" != "$bare_b" ]; then
    pass "sdd-dir without a plan keys by the cwd's repository"
else
    fail "sdd-dir without a plan keys by the cwd's repository (both: $bare_a)"
fi

# 10e. A plan outside any repository is refused. TEST_ROOT is a mktemp -d
# directory, outside any repository, so nowhere/ has no enclosing repo.
plan_nowhere="$TEST_ROOT/nowhere/plan.md"
mkdir -p "$(dirname "$plan_nowhere")"
: > "$plan_nowhere"
if (cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$plan_nowhere" >/dev/null 2>&1); then
    fail "sdd-dir refuses a plan whose directory is not inside a git repository"
else
    pass "sdd-dir refuses a plan whose directory is not inside a git repository"
fi

# 10f. The key does not depend on the caller's git object format: a plan in a
# SHA-256 repository hashes the same from a SHA-1 cwd as from its own, and a
# SHA-1 plan the same from a SHA-256 cwd.
repo_c="$TEST_ROOT/repo-c"
if git init -q --object-format=sha256 "$repo_c" 2>/dev/null; then
    : > "$repo_c/plan.md"
    from_c=$(cd "$repo_c" && bash "$SDD_DIR_SCRIPT" plan.md)
    from_a_for_c=$(cd "$repo_a" && bash "$SDD_DIR_SCRIPT" "$repo_c/plan.md")
    from_c_for_a=$(cd "$repo_c" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan.md")
    if [ "$from_c" = "$from_a_for_c" ] && [ "$from_c_for_a" = "$from_a" ]; then
        pass "sdd-dir hashes with the plan repository's object format, not the cwd's"
    else
        fail "sdd-dir hashes with the plan repository's object format, not the cwd's (sha256 plan from C: $from_c, from A: $from_a_for_c; sha1 plan from C: $from_c_for_a, from A: $from_a)"
    fi
else
    pass "sdd-dir hashes with the plan repository's object format, not the cwd's (not exercised: this git cannot create a SHA-256 repository)"
fi

# 10g. A cross-repository invocation leaves a pointer under the cwd key, named
# like the workspace, so a reader that only knows the cwd (the compaction
# notice) still finds the ledger. The plan repository's own entry stays a real
# directory.
pointer_b="$bare_b/plans/$(basename "$from_a")+$(basename "$bare_a" | cut -c1-8)"
own_a="$bare_a/plans/$(basename "$from_a")"
if [ -L "$pointer_b" ] && [ "$(cd "$pointer_b" 2>/dev/null && pwd -P)" = "$(cd "$from_a" && pwd -P)" ]; then
    pass "sdd-dir leaves a pointer to a cross-repository plan's workspace under the cwd key"
else
    fail "sdd-dir leaves a pointer to a cross-repository plan's workspace under the cwd key (expected symlink $pointer_b -> $from_a)"
fi
if [ -d "$own_a" ] && [ ! -L "$own_a" ]; then
    pass "sdd-dir keeps the plan repository's own workspace entry a real directory"
else
    fail "sdd-dir keeps the plan repository's own workspace entry a real directory ($own_a)"
fi

# 10h. A cwd key that holds only pointers is refreshed on every cross-
# repository invocation, so the repo-level reclaim (14 idle days, which
# excludes only the plan repository's key) does not take the pointer with it.
touch -t 202601010000 "$bare_b"
from_b_again=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan.md")
if [ "$from_b_again" = "$from_a" ] && [ -L "$pointer_b" ] && [ "$(find "$bare_b" -maxdepth 0 -mtime +14 | wc -l | tr -d ' ')" -eq 0 ]; then
    pass "a cross-repository invocation refreshes the cwd key so its pointer survives the reclaim"
else
    fail "a cross-repository invocation refreshes the cwd key so its pointer survives the reclaim (dir present: $([ -d "$bare_b" ] && echo yes || echo no), pointer present: $([ -L "$pointer_b" ] && echo yes || echo no))"
fi

# 10i. The cwd repository's own plan at the same repo-relative path keeps its
# own real workspace beside the pointer: the two names differ by the plan
# repository's key prefix, so neither shadows the other.
: > "$repo_b/plan.md"
own_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" plan.md)
if [ "$(basename "$own_b")" = "$(basename "$from_a")" ] && [ "$own_b" != "$from_a" ] && [ -d "$own_b" ] && [ ! -L "$own_b" ] && [ -L "$pointer_b" ]; then
    pass "a same-named plan in the cwd repository gets its own workspace beside the pointer"
else
    fail "a same-named plan in the cwd repository gets its own workspace beside the pointer (own: $own_b, link: $([ -L "$own_b" ] && echo yes || echo no), pointer kept: $([ -L "$pointer_b" ] && echo yes || echo no))"
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

echo "Test: symlinked cwd yields the same workspace as the physical path"
make_repo "$TEST_ROOT/repo-symlink"
mkdir -p "$TEST_ROOT/repo-symlink/docs"
echo plan > "$TEST_ROOT/repo-symlink/docs/plan.md"
ln -s "$TEST_ROOT/repo-symlink" "$TEST_ROOT/symlink-to-repo"
physical_dir=$(cd "$TEST_ROOT/repo-symlink" && "$SDD_DIR_SCRIPT" docs/plan.md)
symlink_dir=$(cd "$TEST_ROOT/symlink-to-repo" && "$SDD_DIR_SCRIPT" docs/plan.md)
if [ "$physical_dir" = "$symlink_dir" ]; then pass "symlinked cwd and physical cwd yield identical workspace paths"; else fail "path-form sensitivity: physical=$physical_dir vs symlink=$symlink_dir"; fi

echo ""
echo "Test: review-package rejects ranges that cannot describe a task's work"
make_repo "$TEST_ROOT/repo-range"
mkdir -p "$TEST_ROOT/repo-range/docs"
echo plan > "$TEST_ROOT/repo-range/docs/plan.md"
git -C "$TEST_ROOT/repo-range" add -A
git -C "$TEST_ROOT/repo-range" commit -qm "base"
range_base=$(git -C "$TEST_ROOT/repo-range" rev-parse HEAD)
echo more >> "$TEST_ROOT/repo-range/docs/plan.md"
git -C "$TEST_ROOT/repo-range" commit -qam "work"
range_head=$(git -C "$TEST_ROOT/repo-range" rev-parse HEAD)

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_head" "$range_head" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 3 ]; then pass "empty commit range exits 3"; else fail "empty commit range exits 3 (got rc=$rc)"; fi

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_head" "$range_base" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 3 ]; then pass "non-descendant HEAD exits 3"; else fail "non-descendant HEAD exits 3 (got rc=$rc)"; fi

# A full 40-hex name passes `rev-parse --verify` even when no such object
# exists, so the ancestry check is the first place it can fail. That failure
# (merge-base exit 128) is not "HEAD is not a descendant"; it must be reported
# as an unresolvable base (exit 2) with git's own diagnostic, or a corrupt or
# mistyped SHA reads as a wrong-branch commit.
rc=0; err=""
err=$( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md 0000000000000000000000000000000000000000 "$range_head" 2>&1 >/dev/null ) || rc=$?
if [ "$rc" -eq 2 ]; then pass "an unresolvable ancestry exits 2, not 3"; else fail "an unresolvable ancestry exits 2, not 3 (got rc=$rc)"; fi
case "$err" in *"cannot determine ancestry"*"Not a valid commit name"*) pass "the unresolvable-ancestry message carries git's diagnostic";; *) fail "the unresolvable-ancestry message carries git's diagnostic (got: $err)";; esac

rc=0
( cd "$TEST_ROOT/repo-range" && bash "$REVIEW_PACKAGE" docs/plan.md "$range_base" "$range_head" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then pass "a real range still produces a package"; else fail "a real range still produces a package (got rc=$rc)"; fi

echo ""
echo "Test: helpers still work when an extractor has stripped their exec bits"
make_repo "$TEST_ROOT/repo-nomode"
mkdir -p "$TEST_ROOT/repo-nomode/docs"
printf '### Task 1: Thing\n\nbody\n' > "$TEST_ROOT/repo-nomode/docs/plan.md"
nomode="$TEST_ROOT/nomode-scripts"
mkdir -p "$nomode"
cp "$SDD_DIR_SCRIPT" "$TASK_BRIEF" "$REVIEW_PACKAGE" "$nomode/"
chmod -x "$nomode"/*

rc=0
out=$( ( cd "$TEST_ROOT/repo-nomode" && bash "$nomode/task-brief" docs/plan.md 1 ) 2>&1 ) || rc=$?
if [ "$rc" -eq 0 ]; then pass "task-brief survives stripped exec bits"; else fail "task-brief with stripped exec bits (rc=$rc: $out)"; fi

git -C "$TEST_ROOT/repo-nomode" add -A
git -C "$TEST_ROOT/repo-nomode" commit -qm "base"
nomode_base=$(git -C "$TEST_ROOT/repo-nomode" rev-parse HEAD)
echo more >> "$TEST_ROOT/repo-nomode/docs/plan.md"
git -C "$TEST_ROOT/repo-nomode" commit -qam "work"
nomode_head=$(git -C "$TEST_ROOT/repo-nomode" rev-parse HEAD)
rc=0
( cd "$TEST_ROOT/repo-nomode" && bash "$nomode/review-package" docs/plan.md "$nomode_base" "$nomode_head" ) >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then pass "review-package survives stripped exec bits"; else fail "review-package with stripped exec bits (rc=$rc)"; fi

echo ""
echo "Test: helper stdout matches what the skill docs tell controllers to expect"
make_repo "$TEST_ROOT/repo-stdout"
mkdir -p "$TEST_ROOT/repo-stdout/docs"
printf '### Task 1: Thing\n\nbody\n' > "$TEST_ROOT/repo-stdout/docs/plan.md"
git -C "$TEST_ROOT/repo-stdout" add -A
git -C "$TEST_ROOT/repo-stdout" commit -qm "base"
so_base=$(git -C "$TEST_ROOT/repo-stdout" rev-parse HEAD)
echo more >> "$TEST_ROOT/repo-stdout/docs/plan.md"
git -C "$TEST_ROOT/repo-stdout" commit -qam "work"
so_head=$(git -C "$TEST_ROOT/repo-stdout" rev-parse HEAD)

tb_out=$( cd "$TEST_ROOT/repo-stdout" && bash "$TASK_BRIEF" docs/plan.md 1 )
case "$tb_out" in
    "wrote "*": "*" lines") pass "task-brief prints 'wrote <path>: <N> lines'" ;;
    *) fail "task-brief stdout shape (got: $tb_out)" ;;
esac

rp_out=$( cd "$TEST_ROOT/repo-stdout" && bash "$REVIEW_PACKAGE" docs/plan.md "$so_base" "$so_head" )
case "$rp_out" in
    "wrote "*": "*" commit(s), "*" bytes") pass "review-package prints 'wrote <path>: <N> commit(s), <N> bytes'" ;;
    *) fail "review-package stdout shape (got: $rp_out)" ;;
esac

if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
