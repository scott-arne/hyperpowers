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

STATE_ROOT="$XDG_CACHE_HOME/hyperpowers/state"
LIB="$REPO_ROOT/skills/subagent-driven-development/scripts/sdd-common.sh"
# shellcheck source=/dev/null
state_key() { ( . "$LIB"; hp_key "$1" ); }

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
if grep -q "$expected_path" < <(printf '%s\n' "$default_review_output") && [ -f "$expected_path" ]; then
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
    expected_nonexistent_state="$XDG_CACHE_HOME/hyperpowers/state/$repo_key/plans/$slug-$hash8"
    if [ -d "$expected_nonexistent_dir" ] || [ -d "$expected_nonexistent_state" ]; then
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
# after the workspace with the plan repository's key prefix appended, so a
# reader that only knows the cwd (the compaction notice) still finds the
# ledger. The plan repository's own entry stays a real directory.
pointer_b="$bare_b/plans/$(basename "$from_a")+$(basename "$bare_a" | cut -c1-8)"
if [ -L "$pointer_b" ] && [ "$(cd "$pointer_b" 2>/dev/null && pwd -P)" = "$(cd "$from_a" && pwd -P)" ]; then
    pass "sdd-dir leaves a pointer to a cross-repository plan's workspace under the cwd key"
else
    fail "sdd-dir leaves a pointer to a cross-repository plan's workspace under the cwd key (expected symlink $pointer_b -> $from_a)"
fi
if [ -d "$from_a" ] && [ ! -L "$from_a" ] && [ ! -e "$bare_a/plans/$(basename "$from_a")" ]; then
    pass "the plan repository's workspace is a real directory in its state checkout, with no copy under its plain root"
else
    fail "the plan repository's workspace is a real directory in its state checkout, with no copy under its plain root ($from_a)"
fi

# 10h. A cwd key that holds only pointers is refreshed on every cross-
# repository invocation, so the repo-level reclaim (14 idle days, which
# excludes only the plan repository's key) does not take the pointer with it.
: > "$repo_a/plan2.md"
second_b=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan2.md")
pointer_b2="$bare_b/plans/$(basename "$second_b")+$(state_key "$repo_a" | cut -c1-8)"
touch -t 202601010000 "$bare_b"
from_b_again=$(cd "$repo_b" && bash "$SDD_DIR_SCRIPT" "$repo_a/plan.md")
if [ "$from_b_again" = "$from_a" ] && [ -L "$pointer_b" ] && [ "$(find "$bare_b" -maxdepth 0 -mtime +14 | wc -l | tr -d ' ')" -eq 0 ] && [ -L "$pointer_b2" ]; then
    pass "a cross-repository invocation refreshes the cwd key so its pointers survive the reclaim"
else
    fail "a cross-repository invocation refreshes the cwd key so its pointers survive the reclaim (dir present: $([ -d "$bare_b" ] && echo yes || echo no), pointer present: $([ -L "$pointer_b" ] && echo yes || echo no))"
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
# Backdate after populating: adding the file bumps the dir mtime, and a root
# is idle only when nothing under it is newer than the threshold either.
touch -t 202601010000 "$stale_dir/task-1-brief.md" "$stale_dir"
run_sdd_dir "$repo_a" >/dev/null
if [ ! -d "$stale_dir" ] && ls -d "$stale_dir".reclaiming-* >/dev/null 2>&1; then
    pass "stale sibling scratch dir is claimed for reclaim"
else
    fail "stale sibling scratch dir is claimed for reclaim (still present: $stale_dir)"
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
git -C "$TEST_ROOT/repo-plan" commit -q --allow-empty -m "initial"
mkdir -p "$TEST_ROOT/repo-plan/docs/a" "$TEST_ROOT/repo-plan/docs/b"
echo plan > "$TEST_ROOT/repo-plan/docs/a/plan.md"
echo plan > "$TEST_ROOT/repo-plan/docs/b/plan.md"
noarg=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT")
da=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
db=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
plan_key=$(state_key "$TEST_ROOT/repo-plan")
if [ "$da" != "$db" ]; then pass "same basename, different dirs -> distinct workspaces"; else fail "collision: $da == $db"; fi
case "$da" in "$STATE_ROOT/$plan_key"/plans/plan-*) pass "plan dir nests under the state checkout's plans/ with the slug prefix";; *) fail "unexpected plan dir shape: $da";; esac
case "$noarg" in "$XDG_CACHE_HOME/hyperpowers/sdd/$plan_key") pass "the no-argument root stays in the plain cache under the common-directory key";; *) fail "no-argument root shape: $noarg";; esac
if [ -f "$STATE_ROOT/$plan_key/.git" ] && [ "$(git -C "$STATE_ROOT/$plan_key" branch --show-current)" = "hyperpowers/state" ]; then pass "the checkout is a worktree on hyperpowers/state"; else fail "the checkout is a worktree on hyperpowers/state"; fi
dabs=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$da" = "$dabs" ]; then pass "relative and absolute plan paths agree"; else fail "path-form sensitivity: $da vs $dabs"; fi
git -C "$TEST_ROOT/repo-plan" worktree add -q "$TEST_ROOT/repo-plan-wt" -b wt >/dev/null 2>&1
dwt=$(cd "$TEST_ROOT/repo-plan-wt" && "$SDD_DIR_SCRIPT" "$TEST_ROOT/repo-plan/docs/a/plan.md")
if [ "$dwt" = "$da" ]; then pass "a linked worktree of the clone resolves to the same workspace"; else fail "a linked worktree of the clone resolves to the same workspace ($dwt vs $da)"; fi
: > "$da/task-1-brief.md"; : > "$da/review-1111111..2222222.diff"; : > "$da/progress.md"
if git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/task-1-brief.md" && git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/review-1111111..2222222.diff" && ! git -C "$STATE_ROOT/$plan_key" check-ignore -q "$da/progress.md"; then pass "briefs and packages are ignored in the checkout, the ledger is not"; else fail "briefs and packages are ignored in the checkout, the ledger is not"; fi

echo "Test: nothing inside plans/ is reclaimed automatically"
stale="$STATE_ROOT/$plan_key/plans/old-plan-deadbeef"
nonplan="$noarg/perf-cache-notaplan"
mkdir -p "$stale" "$nonplan"
OLDSTAMP="$(date -v-20d +%Y%m%d%H%M 2>/dev/null || date -d '20 days ago' +%Y%m%d%H%M)"
touch -mt "$OLDSTAMP" "$stale" "$nonplan"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$stale" ]; then pass "an idle sibling plan dir in the checkout is kept (prune is explicit)"; else fail "an idle sibling plan dir in the checkout was removed"; fi
if [ -d "$nonplan" ]; then pass "stale NON-plan content under the plain root preserved"; else fail "reclaim deleted non-plan cache content"; fi
idle_backup="$XDG_CACHE_HOME/hyperpowers/sdd/idlebackup0000000001"
idle_plain="$XDG_CACHE_HOME/hyperpowers/sdd/idleplain00000000002"
mkdir -p "$idle_backup/plans/some-plan-deadbeef.importing-4242" "$idle_plain/plans/some-plan-deadbeef"
: > "$idle_backup/plans/some-plan-deadbeef.importing-4242/progress.md"
find "$idle_backup" "$idle_plain" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$idle_backup" ] && [ ! -d "$idle_plain" ] && ls -d "$idle_plain".reclaiming-* >/dev/null 2>&1; then pass "an idle root holding an import backup survives the reclaim; an idle root without one is claimed"; else fail "an idle root holding an import backup survives the reclaim; an idle root without one is claimed (backup root: $([ -d "$idle_backup" ] && echo kept || echo gone), plain root: $([ -d "$idle_plain" ] && echo kept || echo gone))"; fi
idle_kept="$XDG_CACHE_HOME/hyperpowers/sdd/idlekept0000000000005"
mkdir -p "$idle_kept/plans/some-plan-deadbeef.imported-20240101T000000Z-1"
: > "$idle_kept/plans/some-plan-deadbeef.imported-20240101T000000Z-1/progress.md"
find "$idle_kept" -depth -exec touch -mt "$OLDSTAMP" {} +
# A slower session on the previous plugin still appends to the kept copy.
touch "$idle_kept/plans/some-plan-deadbeef.imported-20240101T000000Z-1/progress.md"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -f "$idle_kept/plans/some-plan-deadbeef.imported-20240101T000000Z-1/progress.md" ]; then pass "an idle root whose kept import copy was written to recently survives"; else fail "an idle root whose kept import copy was written to recently survives (root: $([ -d "$idle_kept" ] && echo kept || echo gone))"; fi
idle_kept_old="$XDG_CACHE_HOME/hyperpowers/sdd/idlekeptold00000000006"
mkdir -p "$idle_kept_old/plans/some-plan-deadbeef.imported-20240101T000000Z-1"
: > "$idle_kept_old/plans/some-plan-deadbeef.imported-20240101T000000Z-1/progress.md"
find "$idle_kept_old" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ ! -d "$idle_kept_old" ] && ls -d "$idle_kept_old".reclaiming-* >/dev/null 2>&1; then pass "an idle root whose kept import copy is old is reclaimed"; else fail "an idle root whose kept import copy is old is reclaimed (root: $([ -d "$idle_kept_old" ] && echo kept || echo gone))"; fi
# Nothing is deleted on the pass that finds a root idle: it is claimed under
# a .reclaiming-<pid> name, and a later call takes it once it has been quiet
# for another 14 days.
idle_two="$XDG_CACHE_HOME/hyperpowers/sdd/idletwophase000000007"
mkdir -p "$idle_two/plans/some-plan-deadbeef"; : > "$idle_two/plans/some-plan-deadbeef/progress.md"
find "$idle_two" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
claimed_two=$(ls -d "$idle_two".reclaiming-* 2>/dev/null | head -n 1) || claimed_two=""
if [ ! -d "$idle_two" ] && [ -n "$claimed_two" ] && [ -f "$claimed_two/plans/some-plan-deadbeef/progress.md" ]; then pass "an idle root is claimed under a .reclaiming-<pid> name and nothing is deleted on that pass"; else fail "an idle root is claimed under a .reclaiming-<pid> name and nothing is deleted on that pass (claimed: '$claimed_two')"; fi
# The claim stamps the tree before the rename, so no call that sees the
# claimed name can read the tree as idle and take it.
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -n "$claimed_two" ] && [ -d "$claimed_two" ] && [ -f "$claimed_two/plans/some-plan-deadbeef/progress.md" ]; then pass "a root claimed by one invocation is not taken by the next"; else fail "a root claimed by one invocation is not taken by the next (claimed: '$claimed_two')"; fi
# A writer on the previous plugin appends to the claimed copy before the
# second phase could take it.
if [ -n "$claimed_two" ]; then
    find "$claimed_two" -depth -exec touch -mt "$OLDSTAMP" {} +
    touch "$claimed_two/plans/some-plan-deadbeef/progress.md"
fi
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -n "$claimed_two" ] && [ -f "$claimed_two/plans/some-plan-deadbeef/progress.md" ]; then pass "a claimed root written to since the claim survives the next invocation"; else fail "a claimed root written to since the claim survives the next invocation (claimed: $([ -n "$claimed_two" ] && [ -d "$claimed_two" ] && echo kept || echo gone))"; fi
[ -z "$claimed_two" ] || find "$claimed_two" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -n "$claimed_two" ] && [ ! -d "$claimed_two" ] && ! ls -d "$claimed_two".gone-* >/dev/null 2>&1; then pass "a claimed root quiet for another 14 days is deleted, leaving no .gone-* copy"; else fail "a claimed root quiet for another 14 days is deleted, leaving no .gone-* copy (claimed: $([ -n "$claimed_two" ] && [ -d "$claimed_two" ] && echo kept || echo gone))"; fi
idle_raced="$XDG_CACHE_HOME/hyperpowers/sdd/idleraced000000000003"
mkdir -p "$idle_raced/plans/some-plan-deadbeef"; : > "$idle_raced/plans/some-plan-deadbeef/progress.md"
find "$idle_raced" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && HYPERPOWERS_TEST_RECLAIM_RACE="$idle_raced" "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$idle_raced" ] && [ -f "$idle_raced/plans/some-plan-deadbeef/progress.md" ] && [ -d "$idle_raced/plans/x.importing-1" ] && ! ls -d "$idle_raced.reclaiming-"* >/dev/null 2>&1; then pass "an import that wins the race by an instant gets its root back, backup and all"; else fail "an import that wins the race by an instant gets its root back, backup and all (root: $([ -d "$idle_raced" ] && echo kept || echo gone))"; fi
# An importer between its two steps: it has touched the root and has not yet
# renamed its source aside, so the only signal is the root's own mtime.
idle_touched="$XDG_CACHE_HOME/hyperpowers/sdd/idletouched000000008"
mkdir -p "$idle_touched/plans/some-plan-deadbeef"; : > "$idle_touched/plans/some-plan-deadbeef/progress.md"
find "$idle_touched" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && HYPERPOWERS_TEST_RECLAIM_RACE="touch:$idle_touched" "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$idle_touched" ] && [ -f "$idle_touched/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_touched".claiming-* >/dev/null 2>&1 && ! ls -d "$idle_touched".reclaiming-* >/dev/null 2>&1; then pass "an importer that has only touched the root keeps it under its own name"; else fail "an importer that has only touched the root keeps it under its own name (root: $([ -d "$idle_touched" ] && echo kept || echo gone))"; fi
# The same importer, with a session in the other repository recreating the
# live root while this pass walked the staged tree: BSD mv would nest the
# staged root inside the new one, where no lookup finds it again.
idle_occupied="$XDG_CACHE_HOME/hyperpowers/sdd/idleoccupied00000009"
mkdir -p "$idle_occupied/plans/some-plan-deadbeef"; : > "$idle_occupied/plans/some-plan-deadbeef/progress.md"
find "$idle_occupied" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && HYPERPOWERS_TEST_RECLAIM_RACE="occupy:$idle_occupied" "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/occupy.err")
staged_oc=$(ls -d "$idle_occupied".claiming-* 2>/dev/null | head -n 1) || staged_oc=""
if [ -n "$staged_oc" ] && [ -f "$staged_oc/plans/some-plan-deadbeef/progress.md" ] && [ "$(ls -A "$idle_occupied" | tr '\n' ' ')" = "writer " ] && [ ! -e "$idle_occupied/$(basename "$staged_oc")" ] && grep -q 'occupied again' "$TEST_ROOT/occupy.err"; then pass "a put-back whose root is occupied again leaves the staged copy named, not nested"; else fail "a put-back whose root is occupied again leaves the staged copy named, not nested (staged: '$staged_oc', root: $(ls -A "$idle_occupied" | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/occupy.err"))"; fi
rm -rf "$staged_oc" "$idle_occupied"
# The same put-back one phase later: a quarantine quiet for its second 14
# days is staged under .gone-<pid> before it is deleted, and in that window
# a writer touches the staged tree while a session in the other repository
# recreates the live root.
idle_gone="$XDG_CACHE_HOME/hyperpowers/sdd/idlegone00000000000b.reclaiming-424242"
mkdir -p "$idle_gone/plans/some-plan-deadbeef"; : > "$idle_gone/plans/some-plan-deadbeef/progress.md"
find "$idle_gone" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && HYPERPOWERS_TEST_RECLAIM_RACE="gone:$idle_gone" "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/gone.err")
staged_gn=$(ls -d "$idle_gone".gone-* 2>/dev/null | head -n 1) || staged_gn=""
if [ -n "$staged_gn" ] && [ -f "$staged_gn/plans/some-plan-deadbeef/progress.md" ] && [ "$(ls -A "$idle_gone" | tr '\n' ' ')" = "writer " ] && [ ! -e "$idle_gone/$(basename "$staged_gn")" ] && grep -q 'occupied again' "$TEST_ROOT/gone.err"; then pass "a second-phase put-back whose quarantine is occupied again leaves the staged copy named, not nested"; else fail "a second-phase put-back whose quarantine is occupied again leaves the staged copy named, not nested (staged: '$staged_gn', quarantine: $(ls -A "$idle_gone" | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/gone.err"))"; fi
rm -rf "$staged_gn" "$idle_gone"
# node is on the creation path (hp_materialize_plain publishes through it,
# hp_stamp_ok fingerprints the remote URL with it), so its absence is a
# preflight refusal, not a failure partway through.
nonode="$TEST_ROOT/nonode"; mkdir -p "$nonode"
for c in bash git dirname basename mkdir touch find ls rm cat sed date head tr wc; do ln -sf "$(command -v "$c")" "$nonode/$c"; done
rc=0
err=$(cd "$TEST_ROOT/repo-plan" && PATH="$nonode" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 2 ] && [ "$err" = "sdd-dir: node not found" ]; then pass "sdd-dir refuses with exit 2 when node is not on PATH"; else fail "sdd-dir refuses with exit 2 when node is not on PATH (rc=$rc: $err)"; fi
# The no-argument form reaches none of that: it derives and touches the
# plain root and runs the reclaim, whose only node use reads a missing node
# as a live process, so it adopts no crashed claim and keeps working.
rc=0
out=$(cd "$TEST_ROOT/repo-plan" && PATH="$nonode" bash "$SDD_DIR_SCRIPT" 2>"$TEST_ROOT/nonode-root.err") || rc=$?
if [ "$rc" -eq 0 ] && [ -d "$out" ] && [ "$out" = "$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$TEST_ROOT/repo-plan")" ]; then pass "the no-argument form prints the plain root and exits 0 without node"; else fail "the no-argument form prints the plain root and exits 0 without node (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/nonode-root.err"))"; fi
# A claim whose owner is still running is that call's to finish or put back.
idle_live="$XDG_CACHE_HOME/hyperpowers/sdd/idlelive00000000000a"
mkdir -p "$idle_live.claiming-$$/plans/some-plan-deadbeef"; : > "$idle_live.claiming-$$/plans/some-plan-deadbeef/progress.md"
find "$idle_live.claiming-$$" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -d "$idle_live.claiming-$$" ] && ! ls -d "$idle_live".reclaiming-* >/dev/null 2>&1; then pass "a .claiming-* whose owner is alive is left to its owner"; else fail "a .claiming-* whose owner is alive is left to its owner (staged: $([ -d "$idle_live.claiming-$$" ] && echo kept || echo gone))"; fi
# A claim that crashed between its staging rename and its final one.
sleep 0.01 & crashed_pid=$!; wait "$crashed_pid" 2>/dev/null
idle_crashed="$XDG_CACHE_HOME/hyperpowers/sdd/idlecrashed000000009"
mkdir -p "$idle_crashed.claiming-$crashed_pid/plans/some-plan-deadbeef"; : > "$idle_crashed.claiming-$crashed_pid/plans/some-plan-deadbeef/progress.md"
find "$idle_crashed.claiming-$crashed_pid" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
adopted=$(ls -d "$idle_crashed".reclaiming-* 2>/dev/null | head -n 1) || adopted=""
if [ ! -d "$idle_crashed.claiming-$crashed_pid" ] && [ -n "$adopted" ] && [ -f "$adopted/plans/some-plan-deadbeef/progress.md" ] && [ -z "$(find "$adopted" -maxdepth 0 -mtime +14 2>/dev/null)" ]; then pass "a .claiming-* leftover is adopted as a quarantine with a fresh stamp"; else fail "a .claiming-* leftover is adopted as a quarantine with a fresh stamp (adopted: '$adopted')"; fi
# The touch that stamps a staged tree is what starts its second 14 days.
# A quarantine published without it carries its old timestamps and the next
# call takes it at once, so the name must not be published unless the stamp
# landed. A touch can fail while a rename in the same parent succeeds: the
# timestamp needs ownership or write permission on the tree itself, the
# rename only on the directory above it.
# Only touch is shimmed, and only for a staged name: the directory goes in
# front of the real PATH so everything else resolves as it always does.
faketouch="$TEST_ROOT/faketouch"; mkdir -p "$faketouch"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in *.claiming-*) exit 1 ;; esac; done\nexec %s "$@"\n' "$(command -v touch)" > "$faketouch/touch"
chmod 755 "$faketouch/touch"
idle_stamp="$XDG_CACHE_HOME/hyperpowers/sdd/idlestamp00000000000c"
mkdir -p "$idle_stamp/plans/some-plan-deadbeef"; : > "$idle_stamp/plans/some-plan-deadbeef/progress.md"
find "$idle_stamp" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && PATH="$faketouch:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/stamp.err")
if ! ls -d "$idle_stamp".reclaiming-* >/dev/null 2>&1 && [ -f "$idle_stamp/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_stamp".claiming-* >/dev/null 2>&1 && grep -q 'grace' "$TEST_ROOT/stamp.err"; then pass "a staged tree whose grace stamp cannot be written goes back under its own name, unpublished and named on stderr"; else fail "a staged tree whose grace stamp cannot be written goes back under its own name (staged: $(ls -d "$idle_stamp".claiming-* "$idle_stamp".reclaiming-* 2>/dev/null | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/stamp.err"))"; fi
# With touch working again the root is claimed as usual, and nothing the
# failed pass left behind was deleted on the way.
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
claimed_st=$(ls -d "$idle_stamp".reclaiming-* 2>/dev/null | head -n 1) || claimed_st=""
if [ -n "$claimed_st" ] && [ -f "$claimed_st/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_stamp".gone-* >/dev/null 2>&1; then pass "the next call with a working touch claims the same root, deleting nothing"; else fail "the next call with a working touch claims the same root, deleting nothing (claimed: '$claimed_st')"; fi
rm -rf "$claimed_st"
# The adoption arm is the same rule: a crashed claim whose stamp cannot be
# written stays a claim rather than becoming a quarantine with old times.
sleep 0.01 & stamp_pid=$!; wait "$stamp_pid" 2>/dev/null
idle_adopt="$XDG_CACHE_HOME/hyperpowers/sdd/idleadopt00000000000d"
mkdir -p "$idle_adopt.claiming-$stamp_pid/plans/some-plan-deadbeef"; : > "$idle_adopt.claiming-$stamp_pid/plans/some-plan-deadbeef/progress.md"
find "$idle_adopt.claiming-$stamp_pid" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && PATH="$faketouch:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/adopt.err")
if [ -d "$idle_adopt.claiming-$stamp_pid" ] && [ -f "$idle_adopt.claiming-$stamp_pid/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_adopt".reclaiming-* >/dev/null 2>&1 && grep -q 'grace' "$TEST_ROOT/adopt.err"; then pass "a crashed claim whose grace stamp cannot be written stays a claim, and is named on stderr"; else fail "a crashed claim whose grace stamp cannot be written stays a claim (err: $(tr '\n' '|' < "$TEST_ROOT/adopt.err"))"; fi
rm -rf "$idle_adopt.claiming-$stamp_pid"
# A freshness check reads find's exit status, not just its output. A
# traversal that fails prints nothing and exits non-zero (a permission
# error on one subdirectory, a transient I/O error), and reading that as
# silence would delete a tree that may hold recent writes.
fakefind="$TEST_ROOT/fakefind"; mkdir -p "$fakefind"
# FINDFAIL names the tree the shim fails for, and only for a traversal
# that descends: a permission error on one subdirectory leaves the stat of
# the root itself (-maxdepth 0) working, which is the shape these checks
# have to survive.
# FINDFAIL holds space-separated patterns, each matched on its own: a
# case pattern built from one variable holding a|b is one literal pattern,
# not an alternation.
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = -maxdepth ] && exec %s "$@"; done\nfor p in $FINDFAIL; do case "$1" in $p) exit 1 ;; esac; done\nexec %s "$@"\n' "$(command -v find)" "$(command -v find)" > "$fakefind/find"
chmod 755 "$fakefind/find"
idle_qr="$XDG_CACHE_HOME/hyperpowers/sdd/idlefind00000000000e.reclaiming-424242"
mkdir -p "$idle_qr/plans/some-plan-deadbeef"; : > "$idle_qr/plans/some-plan-deadbeef/progress.md"
find "$idle_qr" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && FINDFAIL='*.reclaiming-* *.gone-*' PATH="$fakefind:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/find1.err")
if [ -f "$idle_qr/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_qr".gone-* >/dev/null 2>&1 && grep -q 'could not be read' "$TEST_ROOT/find1.err"; then pass "a quarantine whose freshness cannot be read is left alone, not deleted"; else fail "a quarantine whose freshness cannot be read is left alone (left: $(ls -d "$idle_qr"* 2>/dev/null | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/find1.err"))"; fi
# The same failure only after the rename-aside: the copy comes back under
# its quarantine name instead of being deleted on an unread tree.
_=$(cd "$TEST_ROOT/repo-plan" && FINDFAIL='*.gone-*' PATH="$fakefind:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/find2.err")
if [ -f "$idle_qr/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_qr".gone-* >/dev/null 2>&1 && grep -q 'could not be read' "$TEST_ROOT/find2.err"; then pass "a staged copy whose freshness cannot be read after the rename is put back under its quarantine name"; else fail "a staged copy whose freshness cannot be read after the rename is put back (left: $(ls -d "$idle_qr"* 2>/dev/null | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/find2.err"))"; fi
rm -rf "$idle_qr"
# Phase one asks the same question of a live root, and claims nothing when
# it cannot be answered.
idle_p1="$XDG_CACHE_HOME/hyperpowers/sdd/idlefindone0000000f"
mkdir -p "$idle_p1/plans/some-plan-deadbeef"; : > "$idle_p1/plans/some-plan-deadbeef/progress.md"
find "$idle_p1" -depth -exec touch -mt "$OLDSTAMP" {} +
_=$(cd "$TEST_ROOT/repo-plan" && FINDFAIL="$idle_p1" PATH="$fakefind:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/find3.err")
if [ -f "$idle_p1/plans/some-plan-deadbeef/progress.md" ] && ! ls -d "$idle_p1".claiming-* >/dev/null 2>&1 && ! ls -d "$idle_p1".reclaiming-* >/dev/null 2>&1 && grep -q 'could not be read' "$TEST_ROOT/find3.err"; then pass "a live root whose age or freshness cannot be read is not claimed"; else fail "a live root whose age or freshness cannot be read is not claimed (left: $(ls -d "$idle_p1"* 2>/dev/null | tr '\n' ' '), err: $(tr '\n' '|' < "$TEST_ROOT/find3.err"))"; fi
rm -rf "$idle_p1"
# The workspace's own link scan follows the same rule: a traversal that
# fails is not an absence of links, and resolving a workspace nobody could
# scan would let one inside it take the ledger's writes out of the cache.
rc=0
err=$(cd "$TEST_ROOT/repo-plan" && FINDFAIL="$da" PATH="$fakefind:$PATH" bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$err" | grep -q 'could not be scanned for symbolic links'; then pass "a workspace whose link scan cannot be read is refused, not resolved"; else fail "a workspace whose link scan cannot be read is refused, not resolved (rc=$rc: $err)"; fi
ln -s "$TEST_ROOT/repo-plan" "$XDG_CACHE_HOME/hyperpowers/sdd/linkedroot0000000004"
touch -h -t 202601010000 "$XDG_CACHE_HOME/hyperpowers/sdd/linkedroot0000000004" 2>/dev/null || true
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
if [ -L "$XDG_CACHE_HOME/hyperpowers/sdd/linkedroot0000000004" ] && [ -d "$TEST_ROOT/repo-plan/.git" ]; then pass "a symlinked cache root is left alone by the reclaim"; else fail "a symlinked cache root is left alone by the reclaim"; fi
rm -f "$XDG_CACHE_HOME/hyperpowers/sdd/linkedroot0000000004"

echo "Test: a plan's workspace survives another plan's invocation"
planA_dir=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/a/plan.md)
touch -mt "$OLDSTAMP" "$planA_dir"
_=$(cd "$TEST_ROOT/repo-plan" && "$SDD_DIR_SCRIPT" docs/b/plan.md)
if [ -d "$planA_dir" ]; then pass "plan A survives plan B's invocation"; else fail "plan A wrongly removed by plan B"; fi

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
echo "Test: review-package reads the objects as they were written, without replace refs or grafts"
raw="$TEST_ROOT/repo-raw"; make_repo "$raw"
mkdir -p "$raw/docs"; echo plan > "$raw/docs/plan.md"; git -C "$raw" add -A; git -C "$raw" commit -qm base
raw_base=$(git -C "$raw" rev-parse HEAD)
printf 'first\n' > "$raw/one.txt"; git -C "$raw" add -A; git -C "$raw" commit -qm "raw work one"
raw_one=$(git -C "$raw" rev-parse HEAD)
printf 'second\n' > "$raw/two.txt"; git -C "$raw" add -A; git -C "$raw" commit -qm "raw work two"
raw_head=$(git -C "$raw" rev-parse HEAD)
raw_tree=$( { git -C "$raw" ls-tree "$raw_head"; printf '100644 blob %s\tunreviewed.txt\n' "$(printf 'unreviewed\n' | git -C "$raw" hash-object -w --stdin)"; } | git -C "$raw" mktree)
git -C "$raw" replace "$raw_head" "$(git -C "$raw" commit-tree "$raw_tree" -p "$raw_one" -m "raw work two")"
rc=0
( cd "$raw" && bash "$REVIEW_PACKAGE" docs/plan.md "$raw_base" "$raw_head" "$TEST_ROOT/raw-replace.diff" ) >/dev/null 2>"$TEST_ROOT/raw-replace.err" || rc=$?
if [ "$rc" -eq 0 ] && grep -q '^+second$' "$TEST_ROOT/raw-replace.diff" && ! grep -q unreviewed "$TEST_ROOT/raw-replace.diff" && ! grep -q 'grafts is deprecated' "$TEST_ROOT/raw-replace.err"; then pass "a replace ref on the head does not change the package"; else fail "a replace ref on the head does not change the package (rc=$rc)"; fi
git -C "$raw" replace -d "$raw_head" >/dev/null
mkdir -p "$raw/.git/info"; printf '%s %s\n' "$raw_head" "$raw_base" > "$raw/.git/info/grafts"
rc=0
( cd "$raw" && bash "$REVIEW_PACKAGE" docs/plan.md "$raw_base" "$raw_head" "$TEST_ROOT/raw-graft.diff" ) >/dev/null 2>"$TEST_ROOT/raw-graft.err" || rc=$?
rm -f "$raw/.git/info/grafts"
if [ "$rc" -eq 0 ] && grep -q ' raw work one$' "$TEST_ROOT/raw-graft.diff" && grep -q ' raw work two$' "$TEST_ROOT/raw-graft.diff" && grep -q '^+first$' "$TEST_ROOT/raw-graft.diff" && ! grep -q 'grafts is deprecated' "$TEST_ROOT/raw-graft.err"; then pass "a graft on the head does not hide commits from the package"; else fail "a graft on the head does not hide commits from the package (rc=$rc)"; fi

echo ""
echo "Test: helpers still work when an extractor has stripped their exec bits"
make_repo "$TEST_ROOT/repo-nomode"
mkdir -p "$TEST_ROOT/repo-nomode/docs"
printf '### Task 1: Thing\n\nbody\n' > "$TEST_ROOT/repo-nomode/docs/plan.md"
nomode="$TEST_ROOT/nomode-scripts"
mkdir -p "$nomode"
cp "$SDD_DIR_SCRIPT" "$TASK_BRIEF" "$REVIEW_PACKAGE" "$(dirname "$SDD_DIR_SCRIPT")/sdd-common.sh" "$(dirname "$SDD_DIR_SCRIPT")/sdd-state" "$nomode/"
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

echo ""
echo "Test: branch availability decides the backend"
make_repo "$TEST_ROOT/repo-remote"
git -C "$TEST_ROOT/repo-remote" commit -q --allow-empty -m "initial"
git -C "$TEST_ROOT/repo-remote" remote add origin "$TEST_ROOT/nowhere.git"
: > "$TEST_ROOT/repo-remote/plan.md"
rc=0
err=$(cd "$TEST_ROOT/repo-remote" && bash "$SDD_DIR_SCRIPT" plan.md 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 2 ] && grep -q 'needs-sync' < <(printf '%s\n' "$err"); then pass "a clone with a remote and no fetch stamp gets needs-sync"; else fail "a clone with a remote and no fetch stamp gets needs-sync (rc=$rc: $err)"; fi
if ( cd "$TEST_ROOT/repo-remote" && bash "$SDD_DIR_SCRIPT" missing.md ) >/dev/null 2>&1; then fail "a plan file that does not exist is refused"; else pass "a plan file that does not exist is refused"; fi
ln -s plan.md "$TEST_ROOT/repo-remote/link-plan.md"
rc=0
out=$(cd "$TEST_ROOT/repo-remote" && bash "$SDD_DIR_SCRIPT" link-plan.md 2>"$TEST_ROOT/link-plan.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'symlink' < <(cat "$TEST_ROOT/link-plan.err"); then pass "a symlinked plan file is refused with exit 2 and a reason"; else fail "a symlinked plan file is refused with exit 2 and a reason (rc=$rc, out='$out', err=$(cat "$TEST_ROOT/link-plan.err" 2>/dev/null))"; fi
make_repo "$TEST_ROOT/repo-plain"
git -C "$TEST_ROOT/repo-plain" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-plain/plan.md"
plain_key=$(state_key "$TEST_ROOT/repo-plain")
out=$(cd "$TEST_ROOT/repo-plain" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null); rc=$?
case "$out" in
    "$XDG_CACHE_HOME/hyperpowers/sdd/$plain_key/plans/plan-"*) pass "a failed worktree add prints the plain-cache workspace" ;;
    *) fail "a failed worktree add prints the plain-cache workspace (rc=$rc: $out)" ;;
esac
out2=$(cd "$TEST_ROOT/repo-plain" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
if [ "$out2" = "$out" ] && [ "$(head -n1 "$STATE_ROOT/$plain_key.backend")" = plain ]; then pass "the plain backend persists for later calls"; else fail "the plain backend persists for later calls"; fi
echo ""
echo "Test: a quarantined dossier stops the plain backend instead of starting a fresh ledger"
# On the plain backend sdd-dir recreates the cache root and the empty
# workspace directory before it calls import, so after another repository's
# reclaim has taken the root the live candidate is an empty directory, not a
# missing one; the dossier waits in the quarantine until phase two deletes it.
make_repo "$TEST_ROOT/repo-quar"
git -C "$TEST_ROOT/repo-quar" commit -q --allow-empty -m "initial"
mkdir -p "$TEST_ROOT/repo-quar/docs/a"; echo plan > "$TEST_ROOT/repo-quar/docs/a/plan.md"
quar_root="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$TEST_ROOT/repo-quar")"
qws=$(cd "$TEST_ROOT/repo-quar" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>/dev/null)
qname=$(basename "$qws")
printf '# SDD ledger — plan: docs/a/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$qws/progress.md"
mv "$quar_root" "$quar_root.reclaiming-424242"
qrepair="rmdir $quar_root/plans/$qname && mv $quar_root.reclaiming-424242/plans/$qname $quar_root/plans/$qname"
rc=0
out=$(cd "$TEST_ROOT/repo-quar" && bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/quar.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -qF "set aside at $quar_root.reclaiming-424242" "$TEST_ROOT/quar.err" && grep -qF "$qrepair" "$TEST_ROOT/quar.err" && grep -q '^sdd-dir: importing a legacy workspace failed' "$TEST_ROOT/quar.err" && [ -f "$quar_root.reclaiming-424242/plans/$qname/progress.md" ]; then pass "a quarantined dossier stops sdd-dir on the plain backend, naming the quarantine and the repair"; else fail "a quarantined dossier stops sdd-dir on the plain backend (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/quar.err"))"; fi
# The repair exactly as the message gives it: the root is there again, so
# only the workspace moves (a whole-root mv would nest it inside).
rmdir "$quar_root/plans/$qname" && mv "$quar_root.reclaiming-424242/plans/$qname" "$quar_root/plans/$qname"
rc=0
out=$(cd "$TEST_ROOT/repo-quar" && bash "$SDD_DIR_SCRIPT" docs/a/plan.md 2>"$TEST_ROOT/quar2.err") || rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$(sed -n 2p "$out/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "after the repair the same call prints the workspace with its ledger"; else fail "after the repair the same call prints the workspace with its ledger (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/quar2.err"))"; fi

echo ""
echo "Test: a legacy workspace is imported on the first call"
make_repo "$TEST_ROOT/repo-legacy"
git -C "$TEST_ROOT/repo-legacy" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-legacy/plan.md"
legacy_key=$(state_key "$TEST_ROOT/repo-legacy")
legacy_hash8=$(printf '%s' "plan.md" | git hash-object --stdin | cut -c1-8)
legacy_ws="$XDG_CACHE_HOME/hyperpowers/sdd/$legacy_key/plans/plan-$legacy_hash8"
mkdir -p "$legacy_ws"; printf '# SDD ledger — plan: plan.md\n' > "$legacy_ws/progress.md"
out=$(cd "$TEST_ROOT/repo-legacy" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
if [ "$out" = "$STATE_ROOT/$legacy_key/plans/plan-$legacy_hash8" ] && [ -f "$out/progress.md" ] && [ -L "$legacy_ws" ]; then pass "the legacy workspace moved into the checkout and left a symlink"; else fail "the legacy workspace moved into the checkout and left a symlink ($out)"; fi

echo ""
echo "Test: an import that leaves a legacy workspace in place is reported on stderr"
make_repo "$TEST_ROOT/repo-skip"
git -C "$TEST_ROOT/repo-skip" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-skip/plan.md"
skip_key=$(state_key "$TEST_ROOT/repo-skip")
skip_hash8=$(printf '%s' "plan.md" | git hash-object --stdin | cut -c1-8)
dest_skip=$(cd "$TEST_ROOT/repo-skip" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
printf '# SDD ledger — plan: plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$dest_skip/progress.md"
legacy_skip="$XDG_CACHE_HOME/hyperpowers/sdd/$skip_key/plans/plan-$skip_hash8"
mkdir -p "$legacy_skip"
printf '# SDD ledger — plan: plan.md\nTask 7: complete (commits 5555555..6666666, review clean)\n' > "$legacy_skip/progress.md"
err=$(cd "$TEST_ROOT/repo-skip" && bash "$SDD_DIR_SCRIPT" plan.md 2>&1 >/dev/null)
if grep -q 'ledger-exists' < <(printf '%s\n' "$err") && [ -d "$legacy_skip" ]; then pass "sdd-dir reports an import that left a legacy workspace behind"; else fail "sdd-dir reports an import that left a legacy workspace behind (stderr: $err)"; fi


echo ""
echo "Test: a workspace path that is a symbolic link is refused"
# plans/<ws>, or plans itself, can be a symbolic link on disk, and
# everything below (the -d fast path, the tomb restore, mkdir -p) follows
# links, so the workspace would resolve, and Setup would write, outside the
# cache.
SDD_STATE_SCRIPT="$(dirname "$SDD_DIR_SCRIPT")/sdd-state"
link_origin="$TEST_ROOT/link-origin.git"
git init -q --bare -b main "$link_origin"
link_a="$TEST_ROOT/link-hostA"
git clone -q "$link_origin" "$link_a" 2>/dev/null
git -C "$link_a" config user.name "Host A"
git -C "$link_a" config user.email "a@example.com"
mkdir -p "$link_a/docs"; : > "$link_a/docs/plan.md"
git -C "$link_a" add docs; git -C "$link_a" commit -qm plan
git -C "$link_a" push -q origin main 2>/dev/null
( cd "$link_a" && bash "$SDD_STATE_SCRIPT" sync docs/plan.md ) >/dev/null 2>&1
ws_link=$(cd "$link_a" && bash "$SDD_DIR_SCRIPT" docs/plan.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\n' > "$ws_link/progress.md"
( cd "$link_a" && bash "$SDD_STATE_SCRIPT" snapshot docs/plan.md ) >/dev/null
git -C "$link_a" push -q origin hyperpowers/state 2>/dev/null
ws_name=$(basename "$ws_link")
outside_link="$TEST_ROOT/link-outside"; mkdir -p "$outside_link"; printf 'untouched\n' > "$outside_link/sentinel"
link_b="$TEST_ROOT/link-hostB"
git clone -q "$link_origin" "$link_b" 2>/dev/null
git -C "$link_b" config user.name "Host B"; git -C "$link_b" config user.email "b@example.com"
( cd "$link_b" && bash "$SDD_STATE_SCRIPT" sync docs/plan.md ) >/dev/null 2>&1
co_b_link="$STATE_ROOT/$(state_key "$link_b")"
# A link where the workspace should be. A commit carrying one is refused
# before the checkout is created (the state suite covers that); this is the
# same shape once it is on disk, whatever put it there.
rm -rf "$co_b_link/plans/$ws_name"
ln -s "$outside_link" "$co_b_link/plans/$ws_name"
rc=0
out=$(cd "$link_b" && bash "$SDD_DIR_SCRIPT" docs/plan.md 2>"$TEST_ROOT/link-ws.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q "plans/$ws_name" "$TEST_ROOT/link-ws.err"; then pass "a workspace that is a symbolic link is refused, naming the link"; else fail "a workspace that is a symbolic link is refused, naming the link (rc=$rc, out='$out', err=$(cat "$TEST_ROOT/link-ws.err"))"; fi
if grep -q '^sdd-dir: .* is a symbolic link' "$TEST_ROOT/link-ws.err"; then pass "the containment refusal under sdd-dir is prefixed sdd-dir"; else fail "the containment refusal under sdd-dir is prefixed sdd-dir ($(head -n 2 "$TEST_ROOT/link-ws.err" | tr '\n' '|'))"; fi
if [ -L "$co_b_link/plans/$ws_name" ] && [ "$(ls -A "$outside_link" | tr '\n' ' ')" = "sentinel " ]; then pass "nothing is created through the link: its target still holds only the sentinel"; else fail "nothing is created through the link ($(ls -A "$outside_link" | tr '\n' ' '))"; fi
# The human removes the link: the workspace resolves again.
rm -f "$co_b_link/plans/$ws_name"
rc=0
out=$(cd "$link_b" && bash "$SDD_DIR_SCRIPT" docs/plan.md 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$co_b_link/plans/$ws_name" ] && [ -d "$out" ] && [ ! -L "$out" ]; then pass "with the link removed the workspace resolves normally"; else fail "with the link removed the workspace resolves normally (rc=$rc: $out)"; fi
# The same for plans/ itself, where the fast path would mkdir the workspace
# inside the link's target.
mv "$co_b_link/plans" "$co_b_link/plans.real"
ln -s "$outside_link" "$co_b_link/plans"
rc=0
out=$(cd "$link_b" && bash "$SDD_DIR_SCRIPT" docs/plan.md 2>"$TEST_ROOT/link-plans.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q "$co_b_link/plans" "$TEST_ROOT/link-plans.err"; then pass "plans/ itself as a symbolic link is refused, naming the link"; else fail "plans/ itself as a symbolic link is refused, naming the link (rc=$rc, out='$out', err=$(cat "$TEST_ROOT/link-plans.err"))"; fi
if [ -L "$co_b_link/plans" ] && [ "$(ls -A "$outside_link" | tr '\n' ' ')" = "sentinel " ]; then pass "no workspace is created inside the link's target"; else fail "no workspace is created inside the link's target ($(ls -A "$outside_link" | tr '\n' ' '))"; fi
rm -f "$co_b_link/plans"; mv "$co_b_link/plans.real" "$co_b_link/plans"

echo ""
echo "Test: a workspace that holds a symbolic link is refused"
# Setup and the implementers write into the workspace by path: a link
# anywhere inside it would take those writes out of the cache, whoever put
# it there.
make_repo "$TEST_ROOT/repo-wslink"
git -C "$TEST_ROOT/repo-wslink" commit -q --allow-empty -m "initial"
: > "$TEST_ROOT/repo-wslink/plan.md"
ws_link_dir=$(cd "$TEST_ROOT/repo-wslink" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null)
scratch_wslink="$TEST_ROOT/wslink-scratch"; mkdir -p "$scratch_wslink"; printf 'untouched\n' > "$scratch_wslink/victim"
rm -f "$ws_link_dir/progress.md"
ln -s "$scratch_wslink/victim" "$ws_link_dir/progress.md"
rc=0
out=$(cd "$TEST_ROOT/repo-wslink" && bash "$SDD_DIR_SCRIPT" plan.md 2>"$TEST_ROOT/wslink.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'refusing to resolve a workspace that holds a symbolic link' "$TEST_ROOT/wslink.err" && grep -q 'progress.md' "$TEST_ROOT/wslink.err"; then pass "a workspace whose ledger is a symbolic link is refused, naming it"; else fail "a workspace whose ledger is a symbolic link is refused, naming it (rc=$rc, out='$out', err=$(cat "$TEST_ROOT/wslink.err"))"; fi
if [ "$(cat "$scratch_wslink/victim")" = "untouched" ]; then pass "the link's target is left as it was"; else fail "the link's target is left as it was"; fi
rm -f "$ws_link_dir/progress.md"; printf '# SDD ledger — plan: plan.md\n' > "$ws_link_dir/progress.md"
rc=0
out=$(cd "$TEST_ROOT/repo-wslink" && bash "$SDD_DIR_SCRIPT" plan.md 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$ws_link_dir" ]; then pass "with the link replaced by a regular file the workspace resolves"; else fail "with the link replaced by a regular file the workspace resolves (rc=$rc: $out)"; fi
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
