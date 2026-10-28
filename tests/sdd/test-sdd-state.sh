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
# As in the sibling suite: a host-global hyperpowers.stateBranch, or a
# clone.defaultRemoteName other than origin, would fail this suite there and
# nowhere else (GIT_CONFIG_GLOBAL needs git 2.32+).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
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
# fp <repo>: the repository's remote fingerprint as the library computes it.
# shellcheck source=/dev/null
fp() { ( . "$LIB"; hp_remote_fingerprint "$1" ); }
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
plans/*/review-*.diff
# A copy an import left beside an entry it could not install: local to that host, for a human to merge.
plans/*/*.from-import'
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
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"
out=$(run_state "$PAIR_A" snapshot docs/plan.md 2>"$TEST_ROOT/ns-snapshot.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'needs-sync' "$TEST_ROOT/ns-snapshot.err"; then pass "snapshot prints status=error when the checkout cannot be created"; else fail "snapshot prints status=error when the checkout cannot be created (rc=$rc: '$out')"; fi
out=$(run_state "$PAIR_A" verify docs/plan.md 2>"$TEST_ROOT/ns-verify.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'needs-sync' "$TEST_ROOT/ns-verify.err"; then pass "verify prints status=error when the checkout cannot be created"; else fail "verify prints status=error when the checkout cannot be created (rc=$rc: '$out')"; fi
printf 'other hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
err=$(ensure "$PAIR_A" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "needs-sync" && printf '%s' "$err" | grep -q "names 'other hyperpowers/state" && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "a stamp for another remote is needs-sync and names the difference"; else fail "a stamp for another remote is needs-sync and names the difference (rc=$rc: $err)"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "sync writes the remote, branch and URL fingerprint into the stamp"; else fail "sync writes the remote, branch and URL fingerprint into the stamp (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
# A repointed remote: the stamp earned against one endpoint must not vouch
# for another once the checkout and the local branch are gone.
git -C "$PAIR_A" worktree remove --force "$STATE_ROOT/$(state_key "$PAIR_A")" >/dev/null 2>&1 || rm -rf "${STATE_ROOT:?}/$(state_key "$PAIR_A")"; git -C "$PAIR_A" worktree prune; git -C "$PAIR_A" branch -D hyperpowers/state >/dev/null 2>&1
url_was=$(git -C "$PAIR_A" remote get-url origin); git -C "$PAIR_A" remote set-url origin "$TEST_ROOT/elsewhere.git"
err=$(ensure "$PAIR_A" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync' && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify hyperpowers/state >/dev/null; then pass "a repointed remote makes the stamp stale: needs-sync and no branch created"; else fail "a repointed remote makes the stamp stale (rc=$rc: $err)"; fi
git -C "$PAIR_A" remote set-url origin "$url_was"
# A fingerprint that cannot be computed stops the sync: nothing is stamped
# and nothing is created.
mkdir -p "$TEST_ROOT/fakebin"; printf '#!/bin/sh\nexit 9\n' > "$TEST_ROOT/fakebin/node"; chmod 755 "$TEST_ROOT/fakebin/node"
rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(cd "$PAIR_A" && PATH="$TEST_ROOT/fakebin:$PATH" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-node.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'could not be fingerprinted' "$TEST_ROOT/p1-node.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "a fingerprint that cannot be computed stops the sync with nothing stamped or created"; else fail "a fingerprint that cannot be computed stops the sync (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-node.err"))"; fi
# A remote repointed while the fetch ran: the stamp must name the endpoint
# that was fetched, so the sync refuses to stamp and nothing is created.
race_b="$TEST_ROOT/p1-race.git"; git init -q --bare -b main "$race_b"
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-after-fetch-set-url:$race_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-race.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'changed during the sync' "$TEST_ROOT/p1-race.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && [ ! -d "$STATE_ROOT/$(state_key "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify hyperpowers/state >/dev/null; then pass "a remote repointed during the fetch is not stamped and nothing is created"; else fail "a remote repointed during the fetch is not stamped and nothing is created (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-race.err"))"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "the next sync fetches the new endpoint and stamps it"; else fail "the next sync fetches the new endpoint and stamps it (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
git -C "$PAIR_A" remote set-url origin "$url_was"
# A remote repointed to another endpoint between the fingerprint and the
# fetch, and back before the stamp: the fetch is pinned to the fingerprinted
# URL, so the other endpoint (which holds a branch under the state name) is
# never contacted, the outcome is still absent, and the stamp stays true.
aba_b="$TEST_ROOT/p1-aba.git"; git init -q --bare -b main "$aba_b"; git -C "$PAIR_A" push -q "$aba_b" main:refs/heads/hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-aba-fetch:$aba_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-aba.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ] && ! git -C "$PAIR_A" rev-parse -q --verify refs/remotes/origin/hyperpowers/state >/dev/null && [ "$(git -C "$PAIR_A" remote get-url origin)" = "$url_was" ]; then pass "a repoint away and back around the fetch never reaches the other endpoint: the fetch is pinned to the fingerprinted URL"; else fail "a repoint away and back around the fetch never reaches the other endpoint (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-aba.err"))"; fi
# A repository that configures the pinned fetch's own alias name could
# shadow the pin (remote.<name>.url is multi-valued, git takes the first):
# the sync refuses by name and stamps nothing.
rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT="sync-shadow-alias:$aba_b" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-shadow.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'configures a remote named hp-fetch-' "$TEST_ROOT/p1-shadow.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ] && ! git -C "$PAIR_A" rev-parse -q --verify refs/remotes/origin/hyperpowers/state >/dev/null; then pass "a repository that configures the pinned alias's name is refused and nothing is stamped"; else fail "a repository that configures the pinned alias's name is refused (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-shadow.err"))"; fi
for sec in $(git -C "$PAIR_A" config --name-only --get-regexp '^remote\.hp-fetch-' | sed 's/\.url$//'); do git -C "$PAIR_A" config --remove-section "$sec"; done
# A git older than 2.31 ignores environment configuration: the sync says
# so instead of failing as offline. The caller's own GIT_CONFIG_* entries
# survive the pin.
real_git=$(command -v git); mkdir -p "$TEST_ROOT/fakegit"; printf '#!/bin/sh\nif [ "$1" = --version ]; then echo "git version 2.30.2"; exit 0; fi\nexec "%s" "$@"\n' "$real_git" > "$TEST_ROOT/fakegit/git"; chmod 755 "$TEST_ROOT/fakegit/git"
out=$(cd "$PAIR_A" && PATH="$TEST_ROOT/fakegit:$PATH" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1-oldgit.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q '2.31 or newer' "$TEST_ROOT/p1-oldgit.err" && [ ! -e "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ]; then pass "a git older than 2.31 is refused by name before the fetch"; else fail "a git older than 2.31 is refused by name before the fetch (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p1-oldgit.err"))"; fi
# The caller's entry is one the fetch depends on: a global policy forbids
# the file transport and only the caller's environment entry allows it, so
# a pin that replaced the caller's entries would end offline (get-url
# expands insteadOf rewrites, so a rewrite cannot play that part).
printf '[protocol "file"]\n\tallow = never\n' > "$TEST_ROOT/p1-global.gitconfig"
out=$(cd "$PAIR_A" && GIT_CONFIG_GLOBAL="$TEST_ROOT/p1-global.gitconfig" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=absent" ] && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_A").fetched")" = "origin hyperpowers/state $(fp "$PAIR_A")" ]; then pass "a caller's own environment configuration survives the pinned fetch"; else fail "a caller's own environment configuration survives the pinned fetch (rc=$rc: $out: $(cat "$STATE_ROOT/$(state_key "$PAIR_A").fetched" 2>/dev/null))"; fi
# Those syncs created the orphan; the checkout, the branch and the stamp go
# again, so the hand-written stamp below is what lets the next creation
# happen.
git -C "$PAIR_A" worktree remove --force "$STATE_ROOT/$(state_key "$PAIR_A")" >/dev/null 2>&1 || rm -rf "${STATE_ROOT:?}/$(state_key "$PAIR_A")"; git -C "$PAIR_A" worktree prune; git -C "$PAIR_A" branch -D hyperpowers/state >/dev/null 2>&1; rm -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
out=$(ensure "$PAIR_A"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $STATE_ROOT/$(state_key "$PAIR_A")" ]; then pass "the stamp allows the orphan"; else fail "the stamp allows the orphan (rc=$rc, '$out')"; fi

# A remote-tracking state branch is checked out with tracking, not recreated.
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
out=$(ensure "$PAIR_B"); rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$PAIR_B" rev-parse hyperpowers/state)" = "$(git -C "$PAIR_A" rev-parse hyperpowers/state)" ] && [ "$(git -C "$PAIR_B" config branch.hyperpowers/state.remote)" = origin ]; then pass "a fetched state branch is checked out tracking the remote"; else fail "a fetched state branch is checked out tracking the remote (rc=$rc)"; fi
# A chained url.<base>.insteadOf rewrite. git applies one rewrite to
# whatever URL a remote carries, so a fetch pinned to the already-rewritten
# URL is rewritten a second time and reaches an endpoint the fingerprint
# never named. The remote's configured URL is rewritten to the good
# repository, and the good repository's path to the evil one.
p1_a="$PAIR_A"
make_pair p1c
chain_a="$PAIR_A"
chain_good="$TEST_ROOT/p1c-good.git"; chain_evil="$TEST_ROOT/p1c-evil.git"
git init -q --bare -b main "$chain_good"; git init -q --bare -b main "$chain_evil"
mkdir -p "$chain_a/docs"; : > "$chain_a/docs/plan.md"; git -C "$chain_a" add docs; git -C "$chain_a" commit -qm plan
# Two state branches built the way this module builds one, so each carries a
# valid root sentinel; only their ledger lines differ.
for side in good evil; do
    src_1c="$TEST_ROOT/p1c-src-$side"; make_repo "$src_1c"
    mkdir -p "$src_1c/docs"; : > "$src_1c/docs/plan.md"; git -C "$src_1c" add docs; git -C "$src_1c" commit -qm plan
    ws_1c=$(ws_path "$src_1c" "$src_1c/docs/plan.md"); mkdir -p "$ws_1c"
    printf '# SDD ledger — plan: docs/plan.md\nTask 1: the %s endpoint\n' "$side" > "$ws_1c/progress.md"
    run_state "$src_1c" snapshot docs/plan.md >/dev/null
    git -C "$src_1c" push -q "$TEST_ROOT/p1c-$side.git" hyperpowers/state:refs/heads/hyperpowers/state 2>/dev/null
done
name_1c=$(basename "$ws_1c")
url_1c=$(git -C "$chain_a" config --get remote.origin.url)
git -C "$chain_a" remote set-url origin chain:origin
git -C "$chain_a" config "url.$chain_good.insteadOf" chain:origin
git -C "$chain_a" config "url.$chain_evil.insteadOf" "$chain_good"
out=$(run_state "$chain_a" sync docs/plan.md 2>"$TEST_ROOT/p1c.err"); rc=$?
co_1c="$STATE_ROOT/$(state_key "$chain_a")"
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=created" ] && grep -q '^Task 1: the good endpoint$' "$co_1c/plans/$name_1c/progress.md" && ! grep -q 'evil endpoint' "$co_1c/plans/$name_1c/progress.md" && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$chain_a").fetched")" = "origin hyperpowers/state $(fp "$chain_a")" ]; then pass "a chained insteadOf rewrite cannot move the pinned fetch: the once-rewritten endpoint is reconciled and stamped"; else fail "a chained insteadOf rewrite cannot move the pinned fetch (rc=$rc: $out: $(sed -n 2p "$co_1c/plans/$name_1c/progress.md" 2>/dev/null): $(tr '\n' '|' < "$TEST_ROOT/p1c.err"))"; fi
git -C "$chain_a" remote set-url origin "$url_1c"
git -C "$chain_a" config --remove-section "url.$chain_good"
git -C "$chain_a" config --remove-section "url.$chain_evil"
# A remote repointed between the read of its URL and the fetch, and put
# back before the stamp. The URL is read once and the endpoint the fetch
# will contact is derived from that captured string, so the repoint reaches
# nothing; a second read of the remote's configuration would have pinned
# the other endpoint while both fingerprint checks still saw this one.
make_pair p1r
read_a="$PAIR_A"
mkdir -p "$read_a/docs"; : > "$read_a/docs/plan.md"; git -C "$read_a" add docs; git -C "$read_a" commit -qm plan
git -C "$read_a" remote set-url origin "$chain_good"
out=$(cd "$read_a" && HYPERPOWERS_TEST_WRITER_AT="sync-after-url-read:$chain_evil" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1r.err"); rc=$?
co_1r="$STATE_ROOT/$(state_key "$read_a")"
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=created" ] && [ "$(git -C "$read_a" rev-parse hyperpowers/state)" = "$(git -C "$chain_good" rev-parse hyperpowers/state)" ] && grep -q '^Task 1: the good endpoint$' "$co_1r/plans/$name_1c/progress.md" && ! grep -q 'evil endpoint' "$co_1r/plans/$name_1c/progress.md" && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$read_a").fetched")" = "origin hyperpowers/state $(fp "$read_a")" ]; then pass "a remote repointed right after its URL is read cannot move the fetch: the configured endpoint is reconciled and stamped"; else fail "a remote repointed right after its URL is read cannot move the fetch (rc=$rc: $out: $(sed -n 2p "$co_1r/plans/$name_1c/progress.md" 2>/dev/null): $(tr '\n' '|' < "$TEST_ROOT/p1r.err"))"; fi
# A url.<base>.insteadOf rule added after the probe. The probe and the
# fetch are separate git invocations, so a rule that appears between them
# would rewrite the captured string a second way while both fingerprint
# checks still agreed; the fetch carries a one-time name instead, which no
# rule can have been written for.
make_pair p1w
rule_a="$PAIR_A"
mkdir -p "$rule_a/docs"; : > "$rule_a/docs/plan.md"; git -C "$rule_a" add docs; git -C "$rule_a" commit -qm plan
git -C "$rule_a" remote set-url origin "$chain_good"
out=$(cd "$rule_a" && HYPERPOWERS_TEST_WRITER_AT="sync-aba-rewrite:$chain_evil" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1w.err"); rc=$?
co_1w="$STATE_ROOT/$(state_key "$rule_a")"
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=created" ] && [ "$(git -C "$rule_a" rev-parse hyperpowers/state)" = "$(git -C "$chain_good" rev-parse hyperpowers/state)" ] && grep -q '^Task 1: the good endpoint$' "$co_1w/plans/$name_1c/progress.md" && ! grep -q 'evil endpoint' "$co_1w/plans/$name_1c/progress.md" && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$rule_a").fetched")" = "origin hyperpowers/state $(fp "$rule_a")" ]; then pass "a rewrite rule added after the probe cannot move the fetch: the probed endpoint is reconciled and stamped"; else fail "a rewrite rule added after the probe cannot move the fetch (rc=$rc: $out: $(sed -n 2p "$co_1w/plans/$name_1c/progress.md" 2>/dev/null): $(tr '\n' '|' < "$TEST_ROOT/p1w.err"))"; fi
# The pin lives in the environment for the length of one fetch: neither the
# alias, nor the one-time name, nor the endpoint it maps to is written to
# the repository's config, and the seam's own rule is gone with it.
if ! git -C "$rule_a" config --get-regexp '^remote\.hp-fetch-' >/dev/null 2>&1 && ! git -C "$rule_a" config --get-regexp '^url\.' >/dev/null 2>&1; then pass "the pinned fetch leaves no alias and no url rewrite in the repository's config"; else fail "the pinned fetch leaves no alias and no url rewrite in the repository's config ($(git -C "$rule_a" config --get-regexp '^remote\.hp-fetch-'; git -C "$rule_a" config --get-regexp '^url\.'))"; fi
# A remote with two URLs. git fetches from the first and git remote get-url
# reports that one, so the single read has to take the first too; reading
# it with config --get would take the last, probe and pin the endpoint the
# fetch was never meant to use, and leave every sync disagreeing with its
# own stamp.
make_pair p1m
multi_a="$PAIR_A"
mkdir -p "$multi_a/docs"; : > "$multi_a/docs/plan.md"; git -C "$multi_a" add docs; git -C "$multi_a" commit -qm plan
git -C "$multi_a" remote set-url origin "$chain_good"
git -C "$multi_a" remote set-url --add origin "$chain_evil"
out=$(run_state "$multi_a" sync docs/plan.md 2>"$TEST_ROOT/p1m.err"); rc=$?
co_1m="$STATE_ROOT/$(state_key "$multi_a")"
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=created" ] && [ "$(git -C "$multi_a" rev-parse hyperpowers/state)" = "$(git -C "$chain_good" rev-parse hyperpowers/state)" ] && grep -q '^Task 1: the good endpoint$' "$co_1m/plans/$name_1c/progress.md" && ! grep -q 'evil endpoint' "$co_1m/plans/$name_1c/progress.md" && [ "$(head -n 1 "$STATE_ROOT/$(state_key "$multi_a").fetched")" = "origin hyperpowers/state $(fp "$multi_a")" ]; then pass "a remote with two URLs is probed, fetched and stamped on the first, the one git itself would fetch from"; else fail "a remote with two URLs is probed, fetched and stamped on the first (rc=$rc: $out: $(sed -n 2p "$co_1m/plans/$name_1c/progress.md" 2>/dev/null): $(tr '\n' '|' < "$TEST_ROOT/p1m.err"))"; fi
# The fetched tip is read from a private ref, refs/hp-fetch/<pid>. Read
# from the shared remote-tracking ref, a fetch another process finished in
# between would hand this sync a commit the pinned endpoint never served.
# The shared ref is published afterwards by compare-and-swap, so the sync
# that won the race keeps it.
make_pair p1p
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa1p=$(run_sdd_dir "$PAIR_A" docs/plan.md); name_1p=$(basename "$wsa1p")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa1p/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b1p="$STATE_ROOT/$(state_key "$PAIR_B")"
held_1p=$(git -C "$PAIR_B" rev-parse refs/remotes/origin/hyperpowers/state)
# A second valid state commit that lives in B's object database and nowhere
# else: the tip a racing fetch would leave in the shared ref.
other_1p=$(printf 'a tip another fetch left behind\n' | git -C "$PAIR_B" -c user.name=t -c user.email=t@example.com commit-tree "$(git -C "$PAIR_B" rev-parse "$held_1p^{tree}")" -p "$held_1p")
printf 'Task 2: complete (commits 3333333..4444444, review clean)\n' >> "$wsa1p/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
served_1p=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
# Two private refs from earlier runs: one whose owner is gone, one whose
# owner is this suite and so still running.
sleep 0.01 & gone_1p=$!; wait "$gone_1p" 2>/dev/null
git -C "$PAIR_B" update-ref "refs/hp-fetch/$gone_1p" "$held_1p"
git -C "$PAIR_B" update-ref "refs/hp-fetch/$$" "$held_1p"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-fetch:$other_1p" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1p.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$co_b1p" rev-parse refs/heads/hyperpowers/state)" = "$served_1p" ] && grep -q '^Task 2: complete' "$co_b1p/plans/$name_1p/progress.md" && [ "$(git -C "$PAIR_B" rev-parse refs/remotes/origin/hyperpowers/state)" = "$other_1p" ]; then pass "the tip a sync reconciles is the one the pinned endpoint served, and a lost compare-and-swap leaves the shared ref to the fetch that won it"; else fail "the tip a sync reconciles is the one the pinned endpoint served (rc=$rc: $out: local=$(git -C "$co_b1p" rev-parse refs/heads/hyperpowers/state), served=$served_1p, other=$other_1p, shared=$(git -C "$PAIR_B" rev-parse refs/remotes/origin/hyperpowers/state))"; fi
if ! git -C "$PAIR_B" rev-parse -q --verify "refs/hp-fetch/$gone_1p" >/dev/null && [ "$(git -C "$PAIR_B" rev-parse -q --verify "refs/hp-fetch/$$")" = "$held_1p" ]; then pass "a private fetch ref whose owner is gone is swept before the fetch, and a live owner's is left alone"; else fail "a private fetch ref whose owner is gone is swept before the fetch (gone: $(git -C "$PAIR_B" rev-parse -q --verify "refs/hp-fetch/$gone_1p" || echo swept), live: $(git -C "$PAIR_B" rev-parse -q --verify "refs/hp-fetch/$$" || echo swept))"; fi
git -C "$PAIR_B" update-ref -d "refs/hp-fetch/$$"
# The same race on a repository that has no local state branch yet. The
# first branch has to come from the tip this sync fetched: a lost swap
# leaves another fetch's tip in the shared ref, and the checkout creation
# reads that ref, so the branch would be seeded from a commit this sync
# never fingerprinted.
make_pair p1n
first_a="$PAIR_A"; first_b="$PAIR_B"
mkdir -p "$first_a/docs"; : > "$first_a/docs/plan.md"; git -C "$first_a" add docs; git -C "$first_a" commit -qm plan; git -C "$first_a" push -q origin main 2>/dev/null
git -C "$first_b" pull -q origin main 2>/dev/null
run_state "$first_a" sync docs/plan.md >/dev/null
wsa1n=$(run_sdd_dir "$first_a" docs/plan.md); name_1n=$(basename "$wsa1n")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa1n/progress.md"
run_state "$first_a" snapshot docs/plan.md >/dev/null; git -C "$first_a" push -q origin hyperpowers/state 2>/dev/null
served_1n=$(git -C "$first_a" rev-parse hyperpowers/state)
# A second valid state commit in B's object database, reached by no ref B
# reads: the tip a racing fetch would leave in the shared ref. B still has
# no local branch, no remote-tracking ref and no checkout.
git -C "$first_b" fetch -q origin "+refs/heads/hyperpowers/state:refs/hp-seed/x" 2>/dev/null
other_1n=$(printf 'a tip another fetch left behind\n' | git -C "$first_b" -c user.name=t -c user.email=t@example.com commit-tree "$(git -C "$first_b" rev-parse "refs/hp-seed/x^{tree}")" -p "$served_1n")
git -C "$first_b" update-ref -d refs/hp-seed/x
co_b1n="$STATE_ROOT/$(state_key "$first_b")"
out=$(cd "$first_b" && HYPERPOWERS_TEST_WRITER_AT="sync-after-fetch:$other_1n" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p1n.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=created" ] && [ "$(git -C "$first_b" rev-parse hyperpowers/state)" = "$served_1n" ] && grep -q '^Task 1: complete' "$co_b1n/plans/$name_1n/progress.md" && [ "$(git -C "$first_b" rev-parse refs/remotes/origin/hyperpowers/state)" = "$other_1n" ]; then pass "the first local branch is created from the fetched tip, not from the shared ref a lost swap left behind"; else fail "the first local branch is created from the fetched tip (rc=$rc: $out: local=$(git -C "$first_b" rev-parse hyperpowers/state 2>/dev/null), served=$served_1n, other=$other_1n: $(tr '\n' '|' < "$TEST_ROOT/p1n.err"))"; fi
if [ "$(git -C "$first_b" config branch.hyperpowers/state.remote)" = origin ] && [ "$(git -C "$first_b" config branch.hyperpowers/state.merge)" = "refs/heads/hyperpowers/state" ]; then pass "the branch this sync created tracks the remote, as the checkout creation's own would"; else fail "the branch this sync created tracks the remote ($(git -C "$first_b" config branch.hyperpowers/state.remote))"; fi
# No private ref outlives a sync, whatever its outcome: the fixtures above
# cover a refused stamp, an absent branch, a refused alias, a pinned fetch,
# a reconciled one and a first checkout created from the fetched tip.
if [ -z "$(git -C "$p1_a" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$chain_a" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$read_a" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$rule_a" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$first_b" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$PAIR_A" for-each-ref refs/hp-fetch)" ] && [ -z "$(git -C "$PAIR_B" for-each-ref refs/hp-fetch)" ]; then pass "no private fetch ref outlives a sync"; else fail "no private fetch ref outlives a sync ($(git -C "$p1_a" for-each-ref refs/hp-fetch; git -C "$chain_a" for-each-ref refs/hp-fetch; git -C "$read_a" for-each-ref refs/hp-fetch; git -C "$rule_a" for-each-ref refs/hp-fetch; git -C "$first_b" for-each-ref refs/hp-fetch; git -C "$PAIR_A" for-each-ref refs/hp-fetch; git -C "$PAIR_B" for-each-ref refs/hp-fetch))"; fi

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
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$keyA.fetched"
coA="$STATE_ROOT/$keyA"
ensure "$PAIR_A" >/dev/null
mkdir -p "$coA/plans/demo-00000000"
printf '# SDD ledger — plan: docs/plan.md\n' > "$coA/plans/demo-00000000/progress.md"
# shellcheck source=/dev/null
( . "$LIB"; hp_commit_paths "$coA" hyperpowers/state "demo ledger" plans/demo-00000000/progress.md >/dev/null )
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_B")" > "$STATE_ROOT/$keyB.fetched"
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
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
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
# The same seam with a commit that passes verification: it carries the
# sentinel, so only its tree gives it away. Local mode adds from the branch
# name, not from the commit hp_refuse_tip validated, so the promotion is
# the last place to catch what actually landed.
r12="$TEST_ROOT/r12"; make_repo "$r12"
ensure "$r12" >/dev/null; co12="$STATE_ROOT/$(state_key "$r12")"
outside_r12="$TEST_ROOT/outside-r12"; mkdir -p "$outside_r12"; printf 'untouched\n' > "$outside_r12/victim"
# <repo> <tip> -> a commit on top of it whose ledger is a link out of the
# cache; the sentinel comes with the tree it reads.
hostile_tip() {
    local idx lb
    idx="$TEST_ROOT/$(basename "$1").hostile.index"
    lb=$(printf '%s' "$outside_r12/victim" | git -C "$1" hash-object -w --stdin)
    rm -f "$idx"; GIT_INDEX_FILE=$idx git -C "$1" read-tree "$2"
    GIT_INDEX_FILE=$idx git -C "$1" update-index --add --cacheinfo "120000,$lb,plans/plan-deadbeef/progress.md"
    printf 'the ledger is a link\n' | git -C "$1" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx git -C "$1" write-tree)" -p "$2"
}
evil12=$(hostile_tip "$r12" "$(git -C "$r12" rev-parse hyperpowers/state)")
git -C "$r12" worktree remove --force "$co12"
out=$(ensure "$r12" "HYPERPOWERS_TEST_SWAP_REF=refs/heads/hyperpowers/state=$evil12" 2> "$TEST_ROOT/r12.err"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'symbolic link' "$TEST_ROOT/r12.err" && grep -q 'plans/plan-deadbeef/progress.md' "$TEST_ROOT/r12.err" && [ ! -e "$co12/.git" ] && ! ls -d "$co12.tmp-"* >/dev/null 2>&1 && [ "$(registrations "$r12")" -eq 0 ] && [ "$(cat "$outside_r12/victim")" = "untouched" ]; then pass "a hostile commit swapped in under the add is refused before the temporary checkout is promoted"; else fail "a hostile commit swapped in under the add is refused before the temporary checkout is promoted (rc=$rc, '$out': $(cat "$TEST_ROOT/r12.err"))"; fi
# The other promotion: a leftover temporary checkout is on the branch and
# its HEAD carries the sentinel, which until its tree is read is all a
# hostile commit needs to be moved into place.
r13="$TEST_ROOT/r13"; make_repo "$r13"
ensure "$r13" >/dev/null; co13="$STATE_ROOT/$(state_key "$r13")"
clean13=$(git -C "$r13" rev-parse hyperpowers/state)
evil13=$(hostile_tip "$r13" "$clean13")
git -C "$r13" worktree remove --force "$co13"
git -C "$r13" update-ref refs/heads/hyperpowers/state "$evil13"
git -C "$r13" worktree add -q "$co13.tmp-1-1" hyperpowers/state >/dev/null 2>&1
out=$(ensure "$r13" 2> "$TEST_ROOT/r13.err"); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'symbolic link' "$TEST_ROOT/r13.err" && [ ! -e "$co13/.git" ] && ! ls -d "$co13.tmp-"* >/dev/null 2>&1 && [ "$(registrations "$r13")" -eq 0 ] && [ "$(cat "$outside_r12/victim")" = "untouched" ]; then pass "a leftover temporary checkout holding a hostile tree is removed instead of promoted"; else fail "a leftover temporary checkout holding a hostile tree is removed instead of promoted (rc=$rc, '$out': $(cat "$TEST_ROOT/r13.err"))"; fi
# update-ref, not branch -f, so the step is the same whether or not the
# refusal above left a worktree holding the branch.
git -C "$r13" update-ref refs/heads/hyperpowers/state "$clean13"
out=$(ensure "$r13" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "branch $co13" ] && [ ! -L "$co13/plans/plan-deadbeef/progress.md" ] && ! ls -d "$co13.tmp-"* >/dev/null 2>&1; then pass "with the branch back at the clean tip the checkout is created from it"; else fail "with the branch back at the clean tip the checkout is created from it (rc=$rc, '$out')"; fi

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
# destination without a ledger is refused rather than cleared, and
# published once a human has removed it; a stale staging directory from an
# interrupted run is removed, and no staging directory remains.
make_pair p4
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
coA4="$STATE_ROOT/$(state_key "$PAIR_A")"
ensure "$PAIR_A" >/dev/null
mkdir -p "$coA4/plans/demo-00000000"
printf '# SDD ledger — plan: docs/plan.md\n' > "$coA4/plans/demo-00000000/progress.md"
printf 'report\n' > "$coA4/plans/demo-00000000/task-1-report.md"
# shellcheck source=/dev/null
( . "$LIB"; hp_commit_paths "$coA4" hyperpowers/state "demo ledger and report" plans/demo-00000000/progress.md plans/demo-00000000/task-1-report.md >/dev/null )
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_B")" > "$STATE_ROOT/$(state_key "$PAIR_B").fetched"
ensure "$PAIR_B" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
plainB4="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$PAIR_B")"; destB4="$plainB4/plans/demo-00000000"
mkdir -p "$destB4" "$plainB4/.materialize.stale/plans/demo-00000000"
printf 'partial\n' > "$destB4/task-1-report.md"
printf 'stale\n' > "$plainB4/.materialize.stale/plans/demo-00000000/progress.md"
materialize "$PAIR_B" demo-00000000 "$destB4"; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cat "$destB4/task-1-report.md")" = partial ] && [ ! -e "$destB4/progress.md" ] && [ ! -e "$plainB4/.materialize.stale" ] && ! ls -d "$plainB4"/.materialize.* >/dev/null 2>&1 && [ "$(cat "$STATE_ROOT/$(state_key "$PAIR_B").backend")" = plain ]; then pass "materialization refuses a partial destination it did not write, sweeps stale staging, and records nothing"; else fail "materialization refuses a partial destination it did not write, sweeps stale staging, and records nothing (rc=$rc)"; fi
rm -rf "$destB4"
materialize "$PAIR_B" demo-00000000 "$destB4"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$destB4/progress.md")" = "# SDD ledger — plan: docs/plan.md" ] && [ "$(cat "$destB4/task-1-report.md")" = report ] && ! ls -d "$plainB4"/.materialize.* >/dev/null 2>&1 && [ "$(cat "$STATE_ROOT/$(state_key "$PAIR_B").backend")" = "plain source=$(git -C "$PAIR_B" rev-parse origin/hyperpowers/state)" ]; then pass "with the destination removed the whole workspace is published by one rename"; else fail "with the destination removed the whole workspace is published by one rename (rc=$rc)"; fi

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
if printf '%s\n' "$outs" | grep -q '^status=claimed task=1 branch=none$' && printf '%s\n' "$outs" | grep -Eq '^status=held task=1 owner=s-(one|two) since=[0-9TZ:-]+ worktree=/'; then pass "the loser's line carries the winner's complete owner record"; else fail "the loser's line carries the winner's complete owner record ($outs)"; fi
winner=$(sed -n 's/^session=//p' "$wsc/claims/task-1/owner")
out=$(run_state "$c1" claim docs/plan.md 1 --session "$winner"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=1 owner=$winner own=1 branch=none" ]; then pass "re-claiming with the owner's own session exits 0"; else fail "re-claiming with the owner's own session exits 0 (rc=$rc: $out)"; fi
if grep -q "^worktree=$c1$" "$wsc/claims/task-1/owner" && grep -q '^checkout=main$' "$wsc/claims/task-1/owner" && grep -q '^host=' "$wsc/claims/task-1/owner"; then pass "the owner record names worktree, branch and host"; else fail "the owner record names worktree, branch and host"; fi
mkdir -p "$wsc/claims/.tmp-prepared"; printf 'session=ghost\n' > "$wsc/claims/.tmp-prepared/owner"
out=$(run_state "$c1" claim docs/plan.md 2 --session s-three); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=2 branch=none" ]; then pass "a prepared but unpublished claim is invisible to the next claimant"; else fail "a prepared but unpublished claim is invisible to the next claimant (rc=$rc: $out)"; fi
out=$(run_state "$c1" claim docs/plan.md 1 --session s-four --takeover); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 takeover=1 branch=none" ] && [ "$(sed -n 's/^session=//p' "$wsc/claims/task-1/owner")" = s-four ] && grep -q "^session=$winner" "$wsc/claims/task-1/owner.history"; then pass "--takeover rewrites the owner and keeps the history"; else fail "--takeover rewrites the owner and keeps the history (rc=$rc: $out)"; fi
run_state "$c1" claim docs/plan.md 3 >/dev/null 2>&1; rc=$?
   if [ "$rc" -eq 2 ] && [ ! -d "$wsc/claims/task-3" ]; then pass "claim without --session is a usage error (exit 2, nothing created)"; else fail "claim without --session is a usage error (rc=$rc)"; fi
bash -c '. "$1"; hp_lock "$2"; sleep 1.5; hp_unlock' _ "$LIB" "$c1" &
sleep 0.3; start=$(date +%s); out=$(run_state "$c1" claim docs/plan.md 4 --session s-seven); end=$(date +%s); wait
if [ "$out" = "status=claimed task=4 branch=none" ] && [ $((end - start)) -ge 1 ]; then pass "claim waits for the repository lock, so it serializes with finish"; else fail "claim waits for the repository lock ($out, waited $((end - start))s)"; fi
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
kept_i1=$(ls -d "$legacy_i1".imported-* 2>/dev/null | head -n 1)
if [ -n "$kept_i1" ] && [ -d "$kept_i1" ] && [ ! -L "$kept_i1" ] && [ "$(head -n 1 "$kept_i1/progress.md")" = "# SDD ledger — plan: $i1/docs/plan.md" ] && cmp -s <(tail -n +2 "$kept_i1/progress.md") <(tail -n +2 "$wsi/progress.md") && [ -f "$kept_i1/task-1-report.md" ] && [ -f "$kept_i1/task-1-brief.md" ] && [ -L "$legacy_i1" ]; then pass "a verified import keeps the legacy workspace as <path>.imported-<UTC>-<pid> beside the pointer, identity line unrewritten"; else fail "a verified import keeps the legacy workspace beside the pointer (kept='$kept_i1')"; fi
if ! ls -d "$legacy_i1".importing-* >/dev/null 2>&1; then pass "no .importing-* copy is left after a complete import"; else fail "no .importing-* copy is left after a complete import"; fi
out=$(run_state "$i1" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none" ] && [ -d "$kept_i1" ]; then pass "the kept copy is not an import candidate: the next import prints status=none and leaves it"; else fail "the kept copy is not an import candidate (rc=$rc: $out)"; fi
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
# An identity naming another repository's plan that EXISTS on this host is
# left alone (the SDD skill's identity check flags it); only a path that does
# not exist here is rewritten by its suffix.
i8a="$TEST_ROOT/i8a"; make_repo "$i8a"; mkdir -p "$i8a/docs"; : > "$i8a/docs/plan.md"; git -C "$i8a" add docs; git -C "$i8a" commit -qm plan
i8b="$TEST_ROOT/i8b"; make_repo "$i8b"; mkdir -p "$i8b/docs"; : > "$i8b/docs/plan.md"; git -C "$i8b" add docs; git -C "$i8b" commit -qm plan
wsi8b=$(ws_path "$i8b" "$i8b/docs/plan.md")
legacy_i8b="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i8b")/plans/$(basename "$wsi8b")"
mkdir -p "$legacy_i8b"; printf '# SDD ledger — plan: %s/docs/plan.md\n' "$i8a" > "$legacy_i8b/progress.md"
out=$(run_state "$i8b" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i8b" ] && [ "$(head -n 1 "$wsi8b/progress.md")" = "# SDD ledger — plan: $i8a/docs/plan.md" ]; then pass "an identity naming another repository's existing plan is not rewritten"; else fail "an identity naming another repository's existing plan is not rewritten (rc=$rc: $out: $(head -n 1 "$wsi8b/progress.md" 2>/dev/null))"; fi

# A failed relink is undone: the source is back as a real directory with its
# files, no backup remains, and the destination holds no ledger.
i9="$TEST_ROOT/i9"; make_repo "$i9"; mkdir -p "$i9/docs"; : > "$i9/docs/plan.md"; git -C "$i9" add docs; git -C "$i9" commit -qm plan
wsi9=$(ws_path "$i9" "$i9/docs/plan.md")
legacy_i9="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i9")/plans/$(basename "$wsi9")"
mkdir -p "$legacy_i9"; printf '# SDD ledger — plan: docs/plan.md\n' > "$legacy_i9/progress.md"; printf 'report\n' > "$legacy_i9/task-1-report.md"
out=$(HYPERPOWERS_TEST_FAIL_RELINK=1 run_state "$i9" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=import-failed from=$legacy_i9" ] && [ -d "$legacy_i9" ] && [ ! -L "$legacy_i9" ] && [ -f "$legacy_i9/progress.md" ] && [ -f "$legacy_i9/task-1-report.md" ] && ! ls -d "$legacy_i9.importing-"* >/dev/null 2>&1 && [ ! -f "$wsi9/progress.md" ]; then pass "a failed relink restores the source and leaves no ledger or backup"; else fail "a failed relink restores the source and leaves no ledger or backup (rc=$rc: $out)"; fi
out=$(run_state "$i9" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i9" ] && [ -L "$legacy_i9" ] && [ -f "$wsi9/progress.md" ]; then pass "the next import succeeds after a failed relink"; else fail "the next import succeeds after a failed relink (rc=$rc: $out)"; fi

# An import interrupted after the source was renamed aside is recovered on
# the next call: the backup is put back, then imported.
i10="$TEST_ROOT/i10"; make_repo "$i10"; mkdir -p "$i10/docs"; : > "$i10/docs/plan.md"; git -C "$i10" add docs; git -C "$i10" commit -qm plan
wsi10=$(ws_path "$i10" "$i10/docs/plan.md")
legacy_i10="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i10")/plans/$(basename "$wsi10")"
mkdir -p "$legacy_i10.importing-424242"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i10.importing-424242/progress.md"
out=$(run_state "$i10" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i10" ] && [ -L "$legacy_i10" ] && [ "$(sed -n 2p "$wsi10/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && ! ls -d "$legacy_i10.importing-"* >/dev/null 2>&1; then pass "an interrupted import's backup is recovered and imported on the next call"; else fail "an interrupted import's backup is recovered and imported on the next call (rc=$rc: $out)"; fi
# A cutover interrupted after publication (destination complete, source still
# in its backup) is finished on the next call; one whose destination differs
# from the source is left as ledger-exists with the source restored.
i11="$TEST_ROOT/i11"; make_repo "$i11"; mkdir -p "$i11/docs"; : > "$i11/docs/plan.md"; git -C "$i11" add docs; git -C "$i11" commit -qm plan
wsi11=$(ws_path "$i11" "$i11/docs/plan.md"); mkdir -p "$wsi11"
legacy_i11="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i11")/plans/$(basename "$wsi11")"
mkdir -p "$legacy_i11.importing-555"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' "$i11" > "$legacy_i11.importing-555/progress.md"
printf 'report\n' > "$legacy_i11.importing-555/task-1-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsi11/progress.md"
printf 'report\n' > "$wsi11/task-1-report.md"
out=$(run_state "$i11" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i11" ] && [ -L "$legacy_i11" ] && ! ls -d "$legacy_i11.importing-"* >/dev/null 2>&1 && [ "$(head -n 1 "$wsi11/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "a cutover interrupted after publication is finished on the next call"; else fail "a cutover interrupted after publication is finished on the next call (rc=$rc: $out)"; fi
i12="$TEST_ROOT/i12"; make_repo "$i12"; mkdir -p "$i12/docs"; : > "$i12/docs/plan.md"; git -C "$i12" add docs; git -C "$i12" commit -qm plan
wsi12=$(ws_path "$i12" "$i12/docs/plan.md"); mkdir -p "$wsi12"
legacy_i12="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i12")/plans/$(basename "$wsi12")"
mkdir -p "$legacy_i12.importing-556"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i12.importing-556/progress.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' > "$wsi12/progress.md"
out=$(run_state "$i12" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=skipped reason=ledger-exists path=$legacy_i12" ] && [ -d "$legacy_i12" ] && [ ! -L "$legacy_i12" ] && [ "$(wc -l < "$wsi12/progress.md" | tr -d ' ')" = 3 ]; then pass "a restored source that differs from the destination is reported, not merged"; else fail "a restored source that differs from the destination is reported, not merged (rc=$rc: $out)"; fi

# An empty pre-existing destination is replaced by the published stage (no
# nesting), and a ledger line appended to the source after the copy was
# taken is carried into the destination before the backup goes.
i13="$TEST_ROOT/i13"; make_repo "$i13"; mkdir -p "$i13/docs"; : > "$i13/docs/plan.md"; git -C "$i13" add docs; git -C "$i13" commit -qm plan
wsi13=$(ws_path "$i13" "$i13/docs/plan.md"); mkdir -p "$wsi13"
legacy_i13="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i13")/plans/$(basename "$wsi13")"
mkdir -p "$legacy_i13"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i13/progress.md"
out=$(HYPERPOWERS_TEST_LATE_APPEND='Task 2: complete (commits 3333333..4444444, review clean)' run_state "$i13" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i13" ] && [ -f "$wsi13/progress.md" ] && [ ! -d "$wsi13/$(basename "$wsi13")" ] && ! ls -d "$wsi13.import-"* >/dev/null 2>&1 && [ "$(tail -n 1 "$wsi13/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ] && ! ls -d "$legacy_i13.importing-"* >/dev/null 2>&1; then pass "an empty destination is replaced in place and a late ledger append is carried over"; else fail "an empty destination is replaced in place and a late ledger append is carried over (rc=$rc: $out)"; fi

# An import interrupted while its candidate was a pointer leaves the pointer
# dangling (its referent is the backup); the next call recovers it and moves
# the referent, relinking the pointer to the new workspace.
i14="$TEST_ROOT/i14"; make_repo "$i14"; mkdir -p "$i14/docs"; : > "$i14/docs/plan.md"; git -C "$i14" add docs; git -C "$i14" commit -qm plan
wsi14=$(ws_path "$i14" "$i14/docs/plan.md")
ptr_dir="$XDG_CACHE_HOME/hyperpowers/sdd/otherkey00000014/plans"; mkdir -p "$ptr_dir"
ptr14="$ptr_dir/$(basename "$wsi14")+$(state_key "$i14" | cut -c1-8)"
referent14="$TEST_ROOT/ptrref14/$(basename "$wsi14")"; mkdir -p "$referent14.importing-777"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$referent14.importing-777/progress.md"
ln -s "$referent14" "$ptr14"
out=$(run_state "$i14" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr14" ] && [ "$(sed -n 2p "$wsi14/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && [ -L "$ptr14" ] && [ "$(cd "$ptr14" && pwd -P)" = "$(cd "$wsi14" && pwd -P)" ] && ! ls -d "$referent14.importing-"* >/dev/null 2>&1; then pass "a dangling pointer whose referent is an interrupted import's backup is recovered and moved"; else fail "a dangling pointer whose referent is an interrupted import's backup is recovered and moved (rc=$rc: $out)"; fi

# A late change that is not an append (the ledger replaced after the copy)
# aborts the import: the source is restored with the new content, nothing
# is moved, and the next import starts over.
i15="$TEST_ROOT/i15"; make_repo "$i15"; mkdir -p "$i15/docs"; : > "$i15/docs/plan.md"; git -C "$i15" add docs; git -C "$i15" commit -qm plan
wsi15=$(ws_path "$i15" "$i15/docs/plan.md")
legacy_i15="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i15")/plans/$(basename "$wsi15")"
mkdir -p "$legacy_i15"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i15/progress.md"
out=$(HYPERPOWERS_TEST_LATE_REPLACE='# SDD ledger — plan: docs/plan.md' run_state "$i15" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=import-failed from=$legacy_i15" ] && [ -d "$legacy_i15" ] && [ ! -L "$legacy_i15" ] && [ "$(wc -l < "$legacy_i15/progress.md" | tr -d ' ')" = 1 ] && [ ! -f "$wsi15/progress.md" ] && ! ls -d "$legacy_i15.importing-"* >/dev/null 2>&1; then pass "a non-append late change aborts the import and restores the current source"; else fail "a non-append late change aborts the import and restores the current source (rc=$rc: $out)"; fi
out=$(run_state "$i15" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i15" ] && [ -L "$legacy_i15" ] && [ "$(wc -l < "$wsi15/progress.md" | tr -d ' ')" = 1 ]; then pass "the next import moves the current source"; else fail "the next import moves the current source (rc=$rc: $out)"; fi

# A cutover interrupted after publication whose source then gained a line
# (the destination is a published prefix of the source) is finished with
# the remainder reconciled, not reported as ledger-exists.
i16="$TEST_ROOT/i16"; make_repo "$i16"; mkdir -p "$i16/docs"; : > "$i16/docs/plan.md"; git -C "$i16" add docs; git -C "$i16" commit -qm plan
wsi16=$(ws_path "$i16" "$i16/docs/plan.md"); mkdir -p "$wsi16"
legacy_i16="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i16")/plans/$(basename "$wsi16")"
mkdir -p "$legacy_i16.importing-616"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i16" > "$legacy_i16.importing-616/progress.md"
printf 'report\n' > "$legacy_i16.importing-616/task-1-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsi16/progress.md"
printf 'report\n' > "$wsi16/task-1-report.md"
out=$(run_state "$i16" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i16" ] && [ -L "$legacy_i16" ] && ! ls -d "$legacy_i16.importing-"* >/dev/null 2>&1 && [ "$(wc -l < "$wsi16/progress.md" | tr -d ' ')" = 3 ] && [ "$(tail -n 1 "$wsi16/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ] && [ "$(head -n 1 "$wsi16/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "an interrupted cutover whose source gained a line is finished with the remainder reconciled"; else fail "an interrupted cutover whose source gained a line is finished with the remainder reconciled (rc=$rc: $out)"; fi

# import touches the legacy root before renaming the source aside, so the
# plain-cache reclaim of idle roots cannot take the backup during the cutover.
i17="$TEST_ROOT/i17"; make_repo "$i17"; mkdir -p "$i17/docs"; : > "$i17/docs/plan.md"; git -C "$i17" add docs; git -C "$i17" commit -qm plan
wsi17=$(ws_path "$i17" "$i17/docs/plan.md")
root_i17="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i17")"
legacy_i17="$root_i17/plans/$(basename "$wsi17")"
mkdir -p "$legacy_i17"; printf '# SDD ledger — plan: docs/plan.md\n' > "$legacy_i17/progress.md"
touch -t 202601010000 "$root_i17"
out=$(run_state "$i17" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i17" ] && [ -z "$(find "$root_i17" -maxdepth 0 -mtime +14 2>/dev/null)" ]; then pass "import refreshes the legacy root before the cutover"; else fail "import refreshes the legacy root before the cutover (rc=$rc: $out)"; fi

# An import killed between the set-aside and the relink leaves the kept copy
# and no pointer; the next import completes the relink.
i22="$TEST_ROOT/i22"; make_repo "$i22"
mkdir -p "$i22/docs"; : > "$i22/docs/plan.md"; git -C "$i22" add docs; git -C "$i22" commit -qm plan
wsi22=$(ws_path "$i22" "$i22/docs/plan.md")
legacy_i22="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i22")/plans/$(basename "$wsi22")"
mkdir -p "$legacy_i22"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i22/progress.md"
( cd "$i22" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ ! -e "$legacy_i22" ] && [ ! -L "$legacy_i22" ] && ls -d "$legacy_i22".imported-* >/dev/null 2>&1 && ! ls -d "$legacy_i22".importing-* >/dev/null 2>&1 && [ -f "$wsi22/progress.md" ]; then pass "the crash seam stops after the set-aside with the kept copy present and no pointer yet"; else fail "the crash seam stops after the set-aside (rc=$rc)"; fi
out=$(run_state "$i22" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i22" ] && [ -L "$legacy_i22" ] && [ "$(cd "$legacy_i22" && pwd -P)" = "$(cd "$wsi22" && pwd -P)" ] && ls -d "$legacy_i22".imported-* >/dev/null 2>&1; then pass "the next import completes the relink and prints status=moved"; else fail "the next import completes the relink (rc=$rc: $out)"; fi
out=$(run_state "$i22" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none" ]; then pass "a completed relink is idempotent: status=none after it"; else fail "a completed relink is idempotent (rc=$rc: $out)"; fi
# The same crash when the candidate is a pointer: the copy sits beside the
# pointer's former referent under another root, not beside the pointer.
i23="$TEST_ROOT/i23"; make_repo "$i23"
mkdir -p "$i23/docs"; : > "$i23/docs/plan.md"; git -C "$i23" add docs; git -C "$i23" commit -qm plan
wsi23=$(ws_path "$i23" "$i23/docs/plan.md")
real_i23="$XDG_CACHE_HOME/hyperpowers/sdd/otherroot00000000000000000000000000000000/plans/$(basename "$wsi23")"
mkdir -p "$real_i23"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$real_i23/progress.md"
ptr_i23="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i23")/plans/$(basename "$wsi23")+$(state_key "$i23" | cut -c1-8)"
mkdir -p "$(dirname "$ptr_i23")"; ln -s "$real_i23" "$ptr_i23"
( cd "$i23" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -L "$ptr_i23" ] && [ ! -e "$ptr_i23" ] && ls -d "$real_i23".imported-* >/dev/null 2>&1 && [ -f "$wsi23/progress.md" ]; then pass "a pointer candidate's crash leaves the kept copy beside its former referent and the pointer dangling"; else fail "a pointer candidate's crash leaves the kept copy beside its former referent (rc=$rc)"; fi
out=$(run_state "$i23" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr_i23" ] && [ "$(cd "$ptr_i23" && pwd -P)" = "$(cd "$wsi23" && pwd -P)" ]; then pass "the next import relinks the dangling pointer to the destination"; else fail "the next import relinks the dangling pointer (rc=$rc: $out)"; fi

# A dangling pointer whose referent carries a kept copy is the interrupted
# import's only handle: another plan's cross-repository call must not prune
# it (sdd-dir's prune loop walks every pointer under the cwd's key).
i24="$TEST_ROOT/i24"; make_repo "$i24"; i24b="$TEST_ROOT/i24b"; make_repo "$i24b"
mkdir -p "$i24/docs"; : > "$i24/docs/plan.md"; : > "$i24/docs/plan2.md"; git -C "$i24" add docs; git -C "$i24" commit -qm plan
wsi24=$(ws_path "$i24" "$i24/docs/plan.md")
real_i24="$XDG_CACHE_HOME/hyperpowers/sdd/otherroot00000000000000000000000000000024/plans/$(basename "$wsi24")"
mkdir -p "$real_i24"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$real_i24/progress.md"
ptr_i24="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i24b")/plans/$(basename "$wsi24")+$(state_key "$i24" | cut -c1-8)"
mkdir -p "$(dirname "$ptr_i24")"; ln -s "$real_i24" "$ptr_i24"
( cd "$i24" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
run_sdd_dir "$i24b" "$i24/docs/plan2.md" >/dev/null 2>&1
if [ "$rc" -eq 99 ] && [ -L "$ptr_i24" ] && [ ! -e "$ptr_i24" ]; then pass "a cross-repository call for another plan keeps the dangling pointer whose referent carries a kept copy"; else fail "a cross-repository call for another plan keeps the dangling pointer (rc=$rc, pointer: $([ -L "$ptr_i24" ] && echo kept || echo gone))"; fi
out=$(run_state "$i24" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr_i24" ] && [ "$(cd "$ptr_i24" && pwd -P)" = "$(cd "$wsi24" && pwd -P)" ]; then pass "the import relinks the pointer the prune kept"; else fail "the import relinks the pointer the prune kept (rc=$rc: $out)"; fi

# The same pointer once the plain-cache reclaim has claimed the referent's
# root: the kept copy moves under <root>.reclaiming-*/plans/, and both the
# prune and the import must still recognize it there.
i25="$TEST_ROOT/i25"; make_repo "$i25"; i25b="$TEST_ROOT/i25b"; make_repo "$i25b"
mkdir -p "$i25/docs"; : > "$i25/docs/plan.md"; : > "$i25/docs/plan2.md"; git -C "$i25" add docs; git -C "$i25" commit -qm plan
wsi25=$(ws_path "$i25" "$i25/docs/plan.md")
root_i25="$XDG_CACHE_HOME/hyperpowers/sdd/otherroot00000000000000000000000000000025"
real_i25="$root_i25/plans/$(basename "$wsi25")"
mkdir -p "$real_i25"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$real_i25/progress.md"
ptr_i25="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i25b")/plans/$(basename "$wsi25")+$(state_key "$i25" | cut -c1-8)"
mkdir -p "$(dirname "$ptr_i25")"; ln -s "$real_i25" "$ptr_i25"
( cd "$i25" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
find "$root_i25" -depth -exec touch -t 202601010000 {} +
# The first call claims the idle root; the second runs its pointer prune
# against the claimed tree.
run_sdd_dir "$i25b" "$i25/docs/plan2.md" >/dev/null 2>&1
run_sdd_dir "$i25b" "$i25/docs/plan2.md" >/dev/null 2>&1
if [ "$rc" -eq 99 ] && [ -L "$ptr_i25" ] && [ ! -e "$ptr_i25" ] && ls -d "$root_i25".reclaiming-*/plans/"$(basename "$wsi25")".imported-* >/dev/null 2>&1; then pass "a quarantined root's kept copy keeps the pointer the prune walks"; else fail "a quarantined root's kept copy keeps the pointer the prune walks (rc=$rc, pointer: $([ -L "$ptr_i25" ] && echo kept || echo gone))"; fi
out=$(run_state "$i25" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$ptr_i25" ] && [ "$(cd "$ptr_i25" && pwd -P)" = "$(cd "$wsi25" && pwd -P)" ]; then pass "the import completes the relink with the kept copy inside a quarantined root"; else fail "the import completes the relink with the kept copy inside a quarantined root (rc=$rc: $out)"; fi

# The same for a direct candidate: the relink has to recreate the legacy
# root's plans directory, which went with the root the reclaim claimed.
i26="$TEST_ROOT/i26"; make_repo "$i26"; i26b="$TEST_ROOT/i26b"; make_repo "$i26b"
mkdir -p "$i26/docs"; : > "$i26/docs/plan.md"; git -C "$i26" add docs; git -C "$i26" commit -qm plan
wsi26=$(ws_path "$i26" "$i26/docs/plan.md")
root_i26="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i26")"
legacy_i26="$root_i26/plans/$(basename "$wsi26")"
mkdir -p "$legacy_i26"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i26/progress.md"
( cd "$i26" && HYPERPOWERS_TEST_CRASH_AT=import-after-set-aside bash "$SDD_STATE" import docs/plan.md >/dev/null 2>&1 ); rc=$?
find "$root_i26" -depth -exec touch -t 202601010000 {} +
# Another repository's call claims the idle root; it never touches this one.
run_sdd_dir "$i26b" >/dev/null 2>&1
if [ "$rc" -eq 99 ] && [ ! -e "$root_i26" ] && ls -d "$root_i26".reclaiming-*/plans/"$(basename "$wsi26")".imported-* >/dev/null 2>&1; then pass "the legacy root of a crashed direct import is claimed with its kept copy"; else fail "the legacy root of a crashed direct import is claimed with its kept copy (rc=$rc)"; fi
out=$(run_state "$i26" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i26" ] && [ -L "$legacy_i26" ] && [ "$(cd "$legacy_i26" && pwd -P)" = "$(cd "$wsi26" && pwd -P)" ]; then pass "the import recreates the legacy root's plans directory and completes the relink"; else fail "the import recreates the legacy root's plans directory and completes the relink (rc=$rc: $out)"; fi
# A legacy workspace the plain-cache reclaim has already set aside is not
# an absent candidate: the dossier waits under the root's quarantine name,
# and an import that passed it by would let sdd-dir start an empty
# workspace beside it.
i27="$TEST_ROOT/i27"; make_repo "$i27"
mkdir -p "$i27/docs"; : > "$i27/docs/plan.md"; git -C "$i27" add docs; git -C "$i27" commit -qm plan
wsi27=$(ws_path "$i27" "$i27/docs/plan.md"); name_i27=$(basename "$wsi27")
root_i27="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i27")"
legacy_i27="$root_i27/plans/$name_i27"
mkdir -p "$legacy_i27"; printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$legacy_i27/progress.md"
mv "$root_i27" "$root_i27.reclaiming-424242"
out=$(run_state "$i27" import docs/plan.md 2>"$TEST_ROOT/i27.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q "set aside at $root_i27.reclaiming-424242;" "$TEST_ROOT/i27.err" && grep -q "mv $root_i27.reclaiming-424242 $root_i27" "$TEST_ROOT/i27.err"; then pass "an import whose legacy root the reclaim set aside ends in error and names the quarantine and the move that repairs it"; else fail "an import whose legacy root the reclaim set aside ends in error and names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/i27.err"))"; fi
rc=0; out=$(run_sdd_dir "$i27" docs/plan.md 2>"$TEST_ROOT/i27-dir.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q "set aside at $root_i27.reclaiming-424242;" "$TEST_ROOT/i27-dir.err" && grep -q "^sdd-dir: importing a legacy workspace failed" "$TEST_ROOT/i27-dir.err"; then pass "sdd-dir stops on it, printing the import's line and its own"; else fail "sdd-dir stops on it, printing the import's line and its own (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/i27-dir.err"))"; fi
# A put-back meets its destination first: BSD mv would nest the quarantine
# inside a root that was recreated meanwhile.
[ ! -e "$root_i27" ] || rmdir "$root_i27"
mv "$root_i27.reclaiming-424242" "$root_i27"
out=$(run_state "$i27" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i27" ] && [ "$(sed -n 2p "$wsi27/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "moved back, the next import completes with the ledger in place"; else fail "moved back, the next import completes with the ledger in place (rc=$rc: $out)"; fi
# The same under the name a claim in progress carries.
i28="$TEST_ROOT/i28"; make_repo "$i28"
mkdir -p "$i28/docs"; : > "$i28/docs/plan.md"; git -C "$i28" add docs; git -C "$i28" commit -qm plan
wsi28=$(ws_path "$i28" "$i28/docs/plan.md")
root_i28="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i28")"
mkdir -p "$root_i28/plans/$(basename "$wsi28")"; printf '# SDD ledger — plan: docs/plan.md\n' > "$root_i28/plans/$(basename "$wsi28")/progress.md"
mv "$root_i28" "$root_i28.claiming-424242"
out=$(run_state "$i28" import docs/plan.md 2>"$TEST_ROOT/i28.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q "set aside at $root_i28.claiming-424242;" "$TEST_ROOT/i28.err"; then pass "a legacy root under a claim in progress is named the same way"; else fail "a legacy root under a claim in progress is named the same way (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/i28.err"))"; fi
# The same once the root is back: on the plain backend sdd-dir recreates it,
# and the empty workspace directory with it, before it calls import, so the
# candidate exists and holds no ledger. The repair then moves the workspace
# and not the root, which a recreated root would nest inside itself.
i29="$TEST_ROOT/i29"; make_repo "$i29"
mkdir -p "$i29/docs"; : > "$i29/docs/plan.md"; git -C "$i29" add docs; git -C "$i29" commit -qm plan
wsi29=$(ws_path "$i29" "$i29/docs/plan.md"); name_i29=$(basename "$wsi29")
root_i29="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i29")"
mkdir -p "$root_i29.reclaiming-424242/plans/$name_i29"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$root_i29.reclaiming-424242/plans/$name_i29/progress.md"
mkdir -p "$root_i29/plans/$name_i29"
repair_i29="rmdir $root_i29/plans/$name_i29 && mv $root_i29.reclaiming-424242/plans/$name_i29 $root_i29/plans/$name_i29"
out=$(run_state "$i29" import docs/plan.md 2>"$TEST_ROOT/i29.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qF "set aside at $root_i29.reclaiming-424242;" "$TEST_ROOT/i29.err" && grep -qF "$repair_i29" "$TEST_ROOT/i29.err"; then pass "a recreated root with an empty workspace beside a quarantine is refused, with the repair that moves the workspace"; else fail "a recreated root with an empty workspace beside a quarantine is refused (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/i29.err"))"; fi
rmdir "$root_i29/plans/$name_i29" && mv "$root_i29.reclaiming-424242/plans/$name_i29" "$root_i29/plans/$name_i29"
out=$(run_state "$i29" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$root_i29/plans/$name_i29" ] && [ "$(sed -n 2p "$wsi29/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "after that repair the import completes with the ledger in place"; else fail "after that repair the import completes with the ledger in place (rc=$rc: $out)"; fi
# The third state: the root is there but the workspace directory is not.
# The no-argument form of sdd-dir creates the root without plans/, so does
# the plan form's pointer bookkeeping, and a human who removed the empty
# directory after an earlier refusal lands here too. The rmdir form would
# fail at its first command and the && would stop the move.
i30="$TEST_ROOT/i30"; make_repo "$i30"
mkdir -p "$i30/docs"; : > "$i30/docs/plan.md"; git -C "$i30" add docs; git -C "$i30" commit -qm plan
wsi30=$(ws_path "$i30" "$i30/docs/plan.md"); name_i30=$(basename "$wsi30")
root_i30="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i30")"
mkdir -p "$root_i30.reclaiming-424242/plans/$name_i30"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$root_i30.reclaiming-424242/plans/$name_i30/progress.md"
mkdir -p "$root_i30"
repair_i30="mkdir -p $root_i30/plans && mv $root_i30.reclaiming-424242/plans/$name_i30 $root_i30/plans/$name_i30"
out=$(run_state "$i30" import docs/plan.md 2>"$TEST_ROOT/i30.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qF "$repair_i30" "$TEST_ROOT/i30.err" && grep -qF "rm -rf \"$root_i30.reclaiming-424242\"" "$TEST_ROOT/i30.err"; then pass "a root without its workspace directory is refused with the repair that creates plans/ first, and the line offers the stale-copy route"; else fail "a root without its workspace directory is refused with the repair that creates plans/ first (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/i30.err"))"; fi
mkdir -p "$root_i30/plans" && mv "$root_i30.reclaiming-424242/plans/$name_i30" "$root_i30/plans/$name_i30"
out=$(run_state "$i30" import docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$root_i30/plans/$name_i30" ] && [ "$(sed -n 2p "$wsi30/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "after that repair the import completes with the ledger in place"; else fail "after that repair the import completes with the ledger in place (rc=$rc: $out)"; fi

echo ""
echo "=== sdd-dir and the plain fallback over branch state ==="
make_pair p5
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
printf 'origin hyperpowers/state %s\n' "$(fp "$PAIR_A")" > "$STATE_ROOT/$(state_key "$PAIR_A").fetched"
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR" docs/plan.md 2>/dev/null)
keyb=$(state_key "$PAIR_B")
if [ "$out" = "$XDG_CACHE_HOME/hyperpowers/sdd/$keyb/plans/$(basename "$wsa")" ] && [ "$(sed -n 2p "$out/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && grep -q "^plain source=$(git -C "$PAIR_B" rev-parse refs/remotes/origin/hyperpowers/state)$" "$STATE_ROOT/$keyb.backend"; then pass "the plain fallback materializes the branch workspace and records its source"; else fail "the plain fallback materializes the branch workspace and records its source ($out)"; fi
if [ ! -d "$STATE_ROOT/$keyb.lock" ]; then pass "the plain materialization released the lock"; else fail "the plain materialization released the lock"; fi
echo ""
echo "=== finish ==="
f1="$TEST_ROOT/f1"; make_repo "$f1"
mkdir -p "$f1/docs"; : > "$f1/docs/plan.md"; git -C "$f1" add docs; git -C "$f1" commit -qm plan
wsf=$(run_sdd_dir "$f1" docs/plan.md); co_f1="$STATE_ROOT/$(state_key "$f1")"
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf/progress.md"
run_state "$f1" claim docs/plan.md 1 --session s-f >/dev/null
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 6 ] && [ "$out" = "status=open-claims tasks=1" ] && [ -d "$wsf" ]; then pass "finish refuses while a claim has no completion line"; else fail "finish refuses while a claim has no completion line (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsf/progress.md"
out=$(run_state "$f1" finish docs/plan.md); rc=$?
last=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
case "$out" in
    "status=finished sha="???????" last="????????????????????????????????????????" push=origin/hyperpowers/state") pass "finish prints the finish sha, the full last sha and the push target" ;;
    *) fail "finish prints the finish sha, the full last sha and the push target (rc=$rc: $out)" ;;
esac
if [ ! -d "$wsf" ] && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf")/"; then pass "finish removes the workspace from the tree and the disk"; else fail "finish removes the workspace from the tree and the disk"; fi
if [ "$(git -C "$co_f1" show "$last:plans/$(basename "$wsf")/progress.md" 2>/dev/null | sed -n 2p)" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "the last sha still shows the ledger"; else fail "the last sha still shows the ledger"; fi
if [ "$(run_state "$f1" finish docs/plan.md)" = "status=none" ]; then pass "finishing twice reports none"; else fail "finishing twice reports none"; fi
wsf3=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf3/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf3")/progress.md" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -d "$wsf3" ] && grep -q '^concurrent write$' "$wsf3/progress.md"; then pass "a line appended between the final snapshot and the removal makes finish busy and keeps the workspace"; else fail "a line appended between the final snapshot and the removal makes finish busy (rc=$rc: $out)"; fi
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ]; then pass "finish succeeds on the retry"; else fail "finish succeeds on the retry (rc=$rc: $out)"; fi
wsf2=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf2/progress.md"
run_state "$f1" claim docs/plan.md 2 --session s-g >/dev/null
out=$(run_state "$f1" finish docs/plan.md --force); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$wsf2" ]; then pass "--force finishes over an open claim"; else fail "--force finishes over an open claim (rc=$rc: $out)"; fi
wsf4=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf4/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf4")/notes.txt" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -f "$wsf4/notes.txt" ] && [ "$(sed -n 2p "$wsf4/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "a file created between the snapshot and the removal makes finish busy and keeps it"; else fail "a file created between the snapshot and the removal makes finish busy (rc=$rc: $out)"; fi
out=$(run_state "$f1" finish docs/plan.md); rc=$?
last4=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf4" ] && [ "$(git -C "$co_f1" show "$last4:plans/$(basename "$wsf4")/notes.txt" 2>/dev/null)" = "concurrent write" ]; then pass "the retry snapshots the new file and finishes"; else fail "the retry snapshots the new file and finishes (rc=$rc: $out)"; fi
wsf5=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf5/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove:plans/$(basename "$wsf5")/task-9-brief.md" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf5" ]; then pass "an ignored file created between the snapshot and the removal does not block finish"; else fail "an ignored file created between the snapshot and the removal does not block finish (rc=$rc: $out)"; fi
wsf6=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf6/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ "$(sed -n 2p "$wsf6/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ] && [ ! -e "$wsf6/task-2-report.md" ] && ! ls -d "$wsf6"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsf6".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "a workspace recreated after the rename-aside is moved beside the restored copy and finish is busy"; else fail "a workspace recreated after the rename-aside is moved beside the restored copy (rc=$rc: $out)"; fi
rm -rf "$wsf6".reappeared-*
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename-changed:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && grep -q '^concurrent write$' "$wsf6/progress.md" && ! ls -d "$wsf6"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsf6".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "a changed copy restored over a recreated workspace is not nested inside it"; else fail "a changed copy restored over a recreated workspace is not nested inside it (rc=$rc: $out; $(ls -a "$wsf6" 2>/dev/null | tr '\n' ' '))"; fi
rm -rf "$wsf6".reappeared-*
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf6" ]; then pass "finish succeeds once the recreated files are out of the way"; else fail "finish succeeds once the recreated files are out of the way (rc=$rc: $out)"; fi
wsf7=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf7/progress.md"
out=$(run_state "$f1" finish docs/plan.md docs/other.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ -d "$wsf7" ]; then pass "a second positional argument is a usage error and finishes nothing"; else fail "a second positional argument is a usage error and finishes nothing (rc=$rc: $out)"; fi
ln -s progress.md "$wsf7/ledger-link"; run_state "$f1" snapshot docs/plan.md >/dev/null
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsf7" ]; then pass "a tracked symlink compares by its link text and does not block finish"; else fail "a tracked symlink compares by its link text and does not block finish (rc=$rc: $out)"; fi
wsf8=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf8/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-before-remove-link:plans/$(basename "$wsf8")/late-link" bash "$SDD_STATE" finish docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && [ -L "$wsf8/late-link" ]; then pass "a symlink created between the snapshot and the removal counts as an extra entry"; else fail "a symlink created between the snapshot and the removal counts as an extra entry (rc=$rc: $out)"; fi
rm -f "$wsf8/late-link"
tomb8="$(dirname "$wsf8")/.removing-$(basename "$wsf8")-424242"; mv "$wsf8" "$tomb8"
out=$(run_state "$f1" finish docs/plan.md 2>/dev/null); rc=$?
last8=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$tomb8" ] && [ ! -d "$wsf8" ] && [ "$(git -C "$co_f1" show "$last8:plans/$(basename "$wsf8")/progress.md" 2>/dev/null | sed -n 2p)" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "a copy left by an interrupted removal is restored and finished, its ledger in history"; else fail "a copy left by an interrupted removal is restored and finished (rc=$rc: $out)"; fi
wsf9=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf9/progress.md"
tomb9="$(dirname "$wsf9")/.removing-$(basename "$wsf9")-434343"; mkdir -p "$tomb9"; printf 'older copy\n' > "$tomb9/progress.md"
err=$(run_state "$f1" finish docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 3 ] && printf '%s' "$err" | grep -q "$tomb9" && [ -d "$wsf9" ] && [ -d "$tomb9" ]; then pass "a leftover copy beside a live workspace makes finish refuse and name the copy"; else fail "a leftover copy beside a live workspace makes finish refuse and name the copy (rc=$rc: $err)"; fi
rm -rf "$tomb9"
out=$(run_state "$f1" finish docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ]; then pass "finish proceeds once the leftover copy is resolved"; else fail "finish proceeds once the leftover copy is resolved (rc=$rc: $out)"; fi
wsf10=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nrestored by sdd-dir\n' > "$wsf10/progress.md"
mv "$wsf10" "$(dirname "$wsf10")/.removing-$(basename "$wsf10")-454545"
out=$(run_sdd_dir "$f1" docs/plan.md)
if [ "$out" = "$wsf10" ] && [ "$(sed -n 2p "$wsf10/progress.md")" = "restored by sdd-dir" ] && ! ls -d "$(dirname "$wsf10")"/.removing-* >/dev/null 2>&1; then pass "sdd-dir brings back a copy left by an interrupted removal instead of creating an empty workspace"; else fail "sdd-dir brings back a copy left by an interrupted removal instead of creating an empty workspace ($out)"; fi
run_state "$f1" finish docs/plan.md >/dev/null
wsf11=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsf11/progress.md"; mkdir "$wsf11/held"; : > "$wsf11/held/f"; chmod 555 "$wsf11/held"
err=$(run_state "$f1" finish docs/plan.md 2>&1 >/dev/null); rc=$?
chmod 755 "$(dirname "$wsf11")"/.removing-*/held 2>/dev/null
if [ "$rc" -eq 0 ] && printf '%s' "$err" | grep -q 'could not delete' && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf11")/" && ls -d "$(dirname "$wsf11")"/.removing-* >/dev/null 2>&1 && [ ! -d "$wsf11" ]; then pass "under the branch backend the removal is committed and a deletion that fails names the surviving copy"; else fail "under the branch backend the removal is committed and a deletion that fails names the surviving copy (rc=$rc: $err)"; fi
rm -rf "$(dirname "$wsf11")"/.removing-*
wsf12=$(run_sdd_dir "$f1" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsf12/progress.md"
out=$(cd "$f1" && HYPERPOWERS_TEST_WRITER_AT="finish-after-verify:task-3-report.md" bash "$SDD_STATE" finish docs/plan.md 2>"$TEST_ROOT/wsf12.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recreated during finish' "$TEST_ROOT/wsf12.err" && ! git -C "$co_f1" ls-tree -r --name-only hyperpowers/state | grep -q "plans/$(basename "$wsf12")/" && [ "$(cat "$wsf12/task-3-report.md")" = "late" ] && [ ! -e "$wsf12/progress.md" ] && ! ls -d "$(dirname "$wsf12")"/.removing-* >/dev/null 2>&1; then pass "a workspace recreated after the verification stays on disk, is named, and never enters the removal commit"; else fail "a workspace recreated after the verification stays on disk, is named, and never enters the removal commit (rc=$rc: $out)"; fi
rm -rf "$wsf12"
wsp=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp/progress.md"
out=$(run_state "$rp" finish docs/plan.md 2>/dev/null)
if [ "$out" = "status=finished backend=plain" ] && [ ! -d "$wsp" ]; then pass "finish under the plain backend removes the plain workspace"; else fail "finish under the plain backend removes the plain workspace ($out)"; fi
wsp2=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp2/progress.md"
out=$(cd "$rp" && HYPERPOWERS_TEST_WRITER_AT="remove-after-rename-changed:task-2-report.md" bash "$SDD_STATE" finish docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && grep -q '^concurrent write$' "$wsp2/progress.md" && ! ls -d "$wsp2"/.removing-* >/dev/null 2>&1 && [ "$(cat "$wsp2".reappeared-*/task-2-report.md 2>/dev/null)" = "written after rename" ]; then pass "under the plain backend a changed copy restored over a recreated workspace is not nested either"; else fail "under the plain backend a changed copy restored over a recreated workspace is not nested (rc=$rc: $out)"; fi
rm -rf "$wsp2".reappeared-*
wsp3=$(run_sdd_dir "$rp" docs/plan.md 2>/dev/null); printf 'x\n' > "$wsp3/progress.md"; mkdir "$wsp3/held"; : > "$wsp3/held/f"; chmod 555 "$wsp3/held"
err=$(run_state "$rp" finish docs/plan.md 2>&1 >/dev/null); rc=$?
chmod 755 "$wsp3/held" 2>/dev/null; chmod 755 "$(dirname "$wsp3")"/.removing-*/held 2>/dev/null
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'could not delete' && [ -f "$wsp3/held/f" ] && ! ls -d "$(dirname "$wsp3")"/.removing-* >/dev/null 2>&1; then pass "under the plain backend a deletion that fails is an error and what remains is restored"; else fail "under the plain backend a deletion that fails is an error and what remains is restored (rc=$rc: $err)"; fi
rm -rf "$wsp3"

echo ""
echo "=== prune ==="
pr="$TEST_ROOT/pr"; make_repo "$pr"
mkdir -p "$pr/docs"; : > "$pr/docs/old plan.md"; : > "$pr/docs/new.md"; git -C "$pr" add docs; git -C "$pr" commit -qm plans
wso=$(run_sdd_dir "$pr" "docs/old plan.md"); wsn=$(run_sdd_dir "$pr" docs/new.md); co_pr="$STATE_ROOT/$(state_key "$pr")"
printf 'old\n' > "$wso/progress.md"; printf 'new\n' > "$wsn/progress.md"
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot "docs/old plan.md" >/dev/null
run_state "$pr" snapshot docs/new.md >/dev/null
touch -t 202601010000 "$wso/progress.md" "$wso"
wso_enc=$(basename "$wso" | sed 's/ /%20/g')
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000"; printf 'gitdir: %s/gone/.git/worktrees/x\n' "$TEST_ROOT" > "$STATE_ROOT/deadkey0000000000000000000000000000000000/.git"
: > "$STATE_ROOT/deadkey0000000000000000000000000000000000.backend"
mkdir -p "$STATE_ROOT/badkey0000000000000000000000000000000000"; printf 'not a gitdir line\n' > "$STATE_ROOT/badkey0000000000000000000000000000000000/.git"
mkdir -p "$STATE_ROOT/relkey0000000000000000000000000000000000/.gitdir-here"; printf 'gitdir: .gitdir-here\n' > "$STATE_ROOT/relkey0000000000000000000000000000000000/.git"
out=$(run_state "$pr" prune --repo "$pr"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=listed plans=$wso_enc checkouts=deadkey0000000000000000000000000000000000 tombs= quarantined=" ] && [ -d "$wso" ]; then pass "prune lists the idle plan (space percent-encoded) and the dead checkout without removing them"; else fail "prune lists the idle plan and the dead checkout without removing them (rc=$rc: $out)"; fi
# A workspace whose freshness cannot be read is not idle: a find that
# fails prints nothing, and reading that as silence would list, and then
# delete, a dossier nobody could walk. The shim leaves a traversal that
# only stats the directory (-maxdepth 0) alone, which is the shape a
# permission error on one subdirectory has.
fakefind_pr="$TEST_ROOT/fakefind-pr"; mkdir -p "$fakefind_pr"
# FINDFAIL holds space-separated patterns, matched one at a time: a case
# pattern built from a single variable is one literal pattern, so two
# patterns in one variable would never match (an empty one merely falls
# through).
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = -maxdepth ] && exec %s "$@"; done\nfor p in $FINDFAIL; do case "$1" in $p) exit 1 ;; esac; done\nexec %s "$@"\n' "$(command -v find)" "$(command -v find)" > "$fakefind_pr/find"
chmod 755 "$fakefind_pr/find"
# The shim splits FINDFAIL on whitespace and this workspace's name holds a
# space, so the pattern stands in for the path with ? where the space is.
findfail_wso="*/plans/$(basename "$wso" | tr ' ' '?')"
out=$(cd "$pr" && FINDFAIL="$findfail_wso" PATH="$fakefind_pr:$PATH" bash "$SDD_STATE" prune --repo "$pr" 2>"$TEST_ROOT/prunefind.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=listed plans= checkouts=deadkey0000000000000000000000000000000000 tombs= quarantined=" ] && [ -d "$wso" ] && grep -qF "the freshness of the workspace at $wso could not be read" "$TEST_ROOT/prunefind.err"; then pass "a plan whose freshness cannot be read is not listed for removal, and prune says so"; else fail "a plan whose freshness cannot be read is not listed for removal, and prune says so (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/prunefind.err"))"; fi
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-before-remove:plans/$(basename "$wso")/progress.md" bash "$SDD_STATE" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans= kept=$wso_enc checkouts=deadkey0000000000000000000000000000000000 tombs= quarantined=" ] && [ -d "$wso" ] && grep -q '^concurrent write$' "$wso/progress.md"; then pass "a workspace written to after selection is kept, line intact"; else fail "a workspace written to after selection is kept (rc=$rc: $out)"; fi
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot "docs/old plan.md" >/dev/null
touch -t 202601010000 "$wso/progress.md" "$wso"
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000"; printf 'gitdir: %s/gone/.git/worktrees/x\n' "$TEST_ROOT" > "$STATE_ROOT/deadkey0000000000000000000000000000000000/.git"
mkdir -p "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock"; printf 'session=s-dead\npid=999999\nhost=h\ntime=2026-01-01T00:00:00Z\n' > "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock/owner"; touch -t 202601010000 "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock"
: > "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock-history"; : > "$STATE_ROOT/deadkey0000000000000000000000000000000000.fetched"
out=$(run_state "$pr" prune --repo "$pr" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pruned plans=$wso_enc kept= checkouts=deadkey0000000000000000000000000000000000 tombs= quarantined=" ] && [ ! -d "$wso" ] && [ -d "$wsn" ] && [ ! -d "$STATE_ROOT/deadkey0000000000000000000000000000000000" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.backend" ] && [ "$(git -C "$co_pr" log -1 --format=%s hyperpowers/state)" = "sdd: prune $(basename "$wso")" ] && ! git -C "$co_pr" ls-tree -r --name-only hyperpowers/state | grep -q "^plans/$(basename "$wso")/"; then pass "prune --apply removes the whole idle plan, space and all, in one commit and the dead checkout"; else fail "prune --apply removes the idle plan in one commit and the dead checkout (rc=$rc: $out)"; fi
if [ ! -d "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.lock-history" ] && [ ! -e "$STATE_ROOT/deadkey0000000000000000000000000000000000.fetched" ]; then pass "a dead checkout's stale lock is taken over and released last, its sidecars gone"; else fail "a dead checkout's stale lock is taken over and released last, its sidecars gone"; fi
if [ -d "$STATE_ROOT/badkey0000000000000000000000000000000000" ]; then pass "a checkout whose .git file cannot be parsed is neither listed nor removed"; else fail "a checkout whose .git file cannot be parsed is neither listed nor removed"; fi
if [ -d "$STATE_ROOT/relkey0000000000000000000000000000000000/.gitdir-here" ]; then pass "a relative gitdir resolves against its checkout and a live one is kept"; else fail "a relative gitdir resolves against its checkout and a live one is kept"; fi
# Copies killed removals left at plans/.removing-<ws>-<pid>: a gone pid,
# older than N days, and a workspace the branch does not track, is listed,
# quarantined by the first --apply, and deleted by a later one once nothing
# in it is newer than N days; a live pid, a young copy, a tracked workspace,
# or a copy written to after its rename is left alone.
sleep 0.01 & tp=$!; wait "$tp" 2>/dev/null
tomb_old="$co_pr/plans/.removing-gone-0badc0de-$tp"; mkdir -p "$tomb_old"; printf 'orphaned copy\n' > "$tomb_old/progress.md"; touch -t 202401010000 "$tomb_old/progress.md" "$tomb_old"
tomb_live="$co_pr/plans/.removing-live-0badc0de-$$"; mkdir -p "$tomb_live"; printf 'held by a live process\n' > "$tomb_live/progress.md"; touch -t 202401010000 "$tomb_live/progress.md" "$tomb_live"
tomb_young="$co_pr/plans/.removing-young-0badc0de-$tp"; mkdir -p "$tomb_young"; printf 'fresh copy\n' > "$tomb_young/progress.md"
tomb_tracked="$co_pr/plans/.removing-$(basename "$wsn")-$tp"; mkdir -p "$tomb_tracked"; printf 'tracked copy\n' > "$tomb_tracked/progress.md"; touch -t 202401010000 "$tomb_tracked/progress.md" "$tomb_tracked"
quar_old="$co_pr/plans/.pruned-gone-0badc0de-$tp"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_old") quarantined=\$"; then pass "prune lists a gone, idle, untracked tomb and nothing else"; else fail "prune lists a gone, idle, untracked tomb and nothing else (rc=$rc: $out)"; fi
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-after-tomb-rename:$(basename "$tomb_old")" bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$tomb_old" ] && [ ! -e "$quar_old" ]; then pass "a tomb written to after its rename is put back by the re-check"; else fail "a tomb written to after its rename is put back by the re-check (rc=$rc: $out)"; fi
touch -t 202401010000 "$tomb_old/progress.md" "$tomb_old"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_old") quarantined=\$" && [ ! -e "$tomb_old" ] && [ -d "$quar_old" ] && [ "$(cat "$quar_old/progress.md")" = "orphaned copy" ] && [ -d "$tomb_live" ] && [ -d "$tomb_young" ] && [ -d "$tomb_tracked" ]; then pass "the first --apply quarantines only the listed tomb, keeping its bytes"; else fail "the first --apply quarantines only the listed tomb (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$quar_old" ]; then pass "a fresh quarantine is not deleted by the next --apply"; else fail "a fresh quarantine is not deleted by the next --apply (rc=$rc: $out)"; fi
touch -t 202401010000 "$quar_old/progress.md" "$quar_old"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=$(basename "$quar_old")\$"; then pass "an idle quarantine is listed for deletion"; else fail "an idle quarantine is listed for deletion (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=$(basename "$quar_old")\$" && [ ! -e "$quar_old" ] && ! ls -d "$quar_old".pruning-* >/dev/null 2>&1; then pass "the later --apply deletes the idle quarantine and verifies it is gone"; else fail "the later --apply deletes the idle quarantine (rc=$rc: $out)"; fi
rm -rf "$tomb_live" "$tomb_young" "$tomb_tracked"
# A crash after the staging rename: the copy sits under a name neither
# phase lists, the next --apply puts it back and quarantines it with a
# fresh clock, and the --apply after that does not delete it.
tomb_cr="$co_pr/plans/.removing-crash-0badc0de-$tp"; mkdir -p "$tomb_cr"; printf 'orphaned copy\n' > "$tomb_cr/progress.md"; touch -t 202401010000 "$tomb_cr/progress.md" "$tomb_cr"
( cd "$pr" && HYPERPOWERS_TEST_CRASH_AT=prune-after-stage bash "$SDD_STATE" prune --repo "$pr" --apply >/dev/null 2>&1 ); rc=$?
stage_cr="$co_pr/plans/.quarantining-crash-0badc0de-$tp"; quar_cr="$co_pr/plans/.pruned-crash-0badc0de-$tp"
if [ "$rc" -eq 99 ] && [ -d "$stage_cr" ] && [ ! -e "$tomb_cr" ] && [ ! -e "$quar_cr" ]; then pass "the crash seam after the staging rename leaves the copy under the staging name only"; else fail "the crash seam after the staging rename leaves the copy under the staging name only (rc=$rc)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$stage_cr" ]; then pass "a staged copy is listed by neither phase"; else fail "a staged copy is listed by neither phase (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs=$(basename "$tomb_cr") quarantined=\$" && [ ! -e "$stage_cr" ] && [ ! -e "$tomb_cr" ] && [ -d "$quar_cr" ] && [ "$(cat "$quar_cr/progress.md")" = "orphaned copy" ]; then pass "the next --apply puts the staged copy back and quarantines it"; else fail "the next --apply puts the staged copy back and quarantines it (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$quar_cr" ]; then pass "a quarantine made after a crash keeps its full grace period"; else fail "a quarantine made after a crash keeps its full grace period (rc=$rc: $out)"; fi
rm -rf "$quar_cr"
# A put-back whose destination is occupied again: the copy stays staged and
# is named, never nested into the new occupant.
tomb_oc="$co_pr/plans/.removing-occupied-0badc0de-$tp"; mkdir -p "$tomb_oc"; printf 'orphaned copy\n' > "$tomb_oc/progress.md"; touch -t 202401010000 "$tomb_oc/progress.md" "$tomb_oc"
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-reoccupy-tomb:$(basename "$tomb_oc")" bash "$SDD_STATE" prune --repo "$pr" --apply 2>"$TEST_ROOT/pr-oc.err"); rc=$?
stage_oc="$co_pr/plans/.quarantining-occupied-0badc0de-$tp"
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -d "$stage_oc" ] && [ "$(cat "$stage_oc/progress.md")" = "orphaned copy" ] && [ -d "$tomb_oc" ] && [ ! -e "$tomb_oc/$(basename "$stage_oc")" ] && grep -q 'occupied again' "$TEST_ROOT/pr-oc.err"; then pass "a put-back whose destination is occupied again leaves the staged copy named, not nested"; else fail "a put-back whose destination is occupied again leaves the staged copy named, not nested (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/pr-oc.err"))"; fi
rm -rf "$tomb_oc" "$stage_oc"
# A quarantine whose deletion fails keeps the copy under the aside name and
# says so; nothing is reported as quarantined.
if [ "$(id -u)" -ne 0 ]; then
  quar_ro="$co_pr/plans/.pruned-ro-0badc0de-$tp"; mkdir -p "$quar_ro/sub"; printf 'orphaned copy\n' > "$quar_ro/sub/held"; touch -t 202401010000 "$quar_ro/sub/held" "$quar_ro/sub" "$quar_ro"; chmod 0555 "$quar_ro/sub"
  out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>"$TEST_ROOT/pr-ro.err"); rc=$?
  aside_ro=$(ls -d "$quar_ro".pruning-* 2>/dev/null | head -n 1)
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " quarantined=\$" && [ -n "$aside_ro" ] && [ -f "$aside_ro/sub/held" ] && grep -q 'could not be removed; remove it by hand' "$TEST_ROOT/pr-ro.err"; then pass "a quarantine whose deletion fails is kept under the aside name and named"; else fail "a quarantine whose deletion fails is kept under the aside name and named (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/pr-ro.err"))"; fi
  chmod 0755 "$aside_ro/sub" 2>/dev/null; rm -rf "$quar_ro" "$aside_ro"
else
  pass "a quarantine whose deletion fails is kept under the aside name and named (skipped: root ignores directory modes)"
fi
out=$(run_state "$pr" prune --repo "$pr" --days 08); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=listed" ]; then pass "--days 08 is read as decimal eight"; else fail "--days 08 is read as decimal eight (rc=$rc: $out)"; fi
: > "$pr/docs/third.md"; git -C "$pr" add docs; git -C "$pr" commit -qm third
wst=$(run_sdd_dir "$pr" docs/third.md); printf 'third\n' > "$wst/progress.md"
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$pr" snapshot docs/third.md >/dev/null
touch -t 202601010000 "$wst/progress.md" "$wst"
out=$(cd "$pr" && HYPERPOWERS_TEST_WRITER_AT="prune-after-verify:$(basename "$wst")/late.md" bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pruned" ] && printf '%s' "$out" | grep -q "plans=$(basename "$wst")" && ! git -C "$co_pr" ls-tree -r --name-only hyperpowers/state | grep -q "^plans/$(basename "$wst")/" && [ "$(cat "$wst/late.md")" = "late" ] && [ ! -e "$wst/progress.md" ] && ! ls -d "$co_pr"/plans/.removing-* >/dev/null 2>&1; then pass "a plan recreated after prune's verification stays on disk and never enters the prune commit"; else fail "a plan recreated after prune's verification stays on disk and never enters the prune commit (rc=$rc: $out)"; fi
rm -rf "$wst"
out=$(run_state "$pr" prune --repo "$pr" --days abc 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ]; then pass "--days rejects a non-numeric value with usage"; else fail "--days rejects a non-numeric value with usage (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" prune --repo "$rp" 2>/dev/null)" = "status=plain" ]; then pass "prune under the plain backend reports plain"; else fail "prune under the plain backend reports plain"; fi
# A plan file named like a leftover: its workspace name never starts with
# a dot, so neither prune's loops nor the apply's scan can take it for one.
: > "$pr/docs/.pruned-demo.md"; git -C "$pr" add docs/.pruned-demo.md; git -C "$pr" commit -qm dotplan
wsd=$(run_sdd_dir "$pr" docs/.pruned-demo.md); printf 'dot plan\n' > "$wsd/progress.md"; run_state "$pr" snapshot docs/.pruned-demo.md >/dev/null
case "$(basename "$wsd")" in pruned-demo-*) pass "a plan file named like a quarantine gets a workspace name without the leading dot" ;; *) fail "a plan file named like a quarantine gets a workspace name without the leading dot (got $(basename "$wsd"))" ;; esac
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$" && [ -f "$wsd/progress.md" ]; then pass "such a workspace is never listed as a tomb or a quarantine"; else fail "such a workspace is never listed as a tomb or a quarantine (rc=$rc: $out)"; fi
# A checkout from before this release may track a workspace named like a
# leftover (a dot-led plan name with an all-decimal hash): a tracked path
# is never a tomb, a quarantine or a staged copy, whatever its name.
for legacy in .removing-legacy-12345678 .pruned-legacy-12345678 .quarantining-legacy-12345678; do mkdir -p "$co_pr/plans/$legacy"; printf 'legacy dossier\n' > "$co_pr/plans/$legacy/progress.md"; done
git -C "$co_pr" add -A plans/ && git -C "$co_pr" commit -qm legacy
for legacy in .removing-legacy-12345678 .pruned-legacy-12345678 .quarantining-legacy-12345678; do touch -t 202401010000 "$co_pr/plans/$legacy/progress.md" "$co_pr/plans/$legacy"; done
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q " tombs= quarantined=\$"; then pass "tracked paths named like leftovers are listed as neither tomb nor quarantine"; else fail "tracked paths named like leftovers are listed as neither tomb nor quarantine (rc=$rc: $out)"; fi
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$co_pr/plans/.removing-legacy-12345678/progress.md" ] && [ -f "$co_pr/plans/.pruned-legacy-12345678/progress.md" ] && [ -f "$co_pr/plans/.quarantining-legacy-12345678/progress.md" ] && [ -z "$(git -C "$co_pr" status --porcelain -- plans/)" ]; then pass "an --apply leaves tracked paths named like leftovers untouched"; else fail "an --apply leaves tracked paths named like leftovers untouched (rc=$rc: $out: $(git -C "$co_pr" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# The same guard alone, with no tomb name beside the staged one: the
# put-back is refused because the branch tracks the path, not because its
# destination is occupied.
quar2="$co_pr/plans/.quarantining-legacy2-12345678"; mkdir -p "$quar2"; printf 'legacy dossier\n' > "$quar2/progress.md"
git -C "$co_pr" add -A plans/ && git -C "$co_pr" commit -qm legacy2
touch -t 202401010000 "$quar2/progress.md" "$quar2"
out=$(cd "$pr" && bash "$SDD_STATE" prune --repo "$pr" --apply 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$quar2/progress.md" ] && [ ! -e "$co_pr/plans/.removing-legacy2-12345678" ] && [ -z "$(git -C "$co_pr" status --porcelain -- plans/)" ]; then pass "a tracked staged-copy name with no tomb name beside it is never put back"; else fail "a tracked staged-copy name with no tomb name beside it is never put back (rc=$rc: $out: $(git -C "$co_pr" status --porcelain -- plans/ | tr '\n' '|'))"; fi
echo ""
echo "=== sync ==="
make_pair p7
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_a="$STATE_ROOT/$(state_key "$PAIR_A")"; co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
case "$out" in "status=absent local="???????" remote=none age="*) pass "a remote without the branch is absent and the orphan is created" ;; *) fail "a remote without the branch is absent and the orphan is created (rc=$rc: $out)" ;; esac
if [ -f "$STATE_ROOT/$(state_key "$PAIR_A").fetched" ]; then pass "a successful fetch writes the stamp"; else fail "a successful fetch writes the stamp"; fi
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa/progress.md"
printf 'report A\n' > "$wsa/task-1-report.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
case "$out" in "status=created local="???????" remote="???????" age="*) pass "the second host creates its checkout from the remote" ;; *) fail "the second host creates its checkout from the remote (rc=$rc: $out)" ;; esac
if [ "$(head -n 1 "$STATE_ROOT/$(state_key "$PAIR_B").fetched")" = "origin hyperpowers/state $(fp "$PAIR_B")" ]; then pass "a fetch that found the branch writes the remote, branch and URL fingerprint into the stamp"; else fail "a fetch that found the branch writes the remote, branch and URL fingerprint into the stamp (got: $(cat "$STATE_ROOT/$(state_key "$PAIR_B").fetched" 2>/dev/null))"; fi
wsb="$co_b/plans/$(basename "$wsa")"
if [ "$(sed -n 2p "$wsb/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "the ledger arrived on the second host"; else fail "the ledger arrived on the second host"; fi
if [ "$(run_state "$PAIR_B" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "a second sync is up-to-date"; else fail "a second sync is up-to-date"; fi
printf 'Task 2: complete (commits 3333333..4444444, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(sed -n 3p "$wsb/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ]; then pass "a behind checkout fast-forwards, after private-index commits left its index stale"; else fail "a behind checkout fast-forwards ($out)"; fi
if [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ] && [ "$(cat "$wsb/progress.md")" = "$(git -C "$co_b" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "after a writer-free fast-forward the checkout is clean and the ledger equals the tree's blob"; else fail "after a writer-free fast-forward the checkout is clean and the ledger equals the tree's blob"; fi
printf 'Task 3: complete (commits 5555555..6666666, review clean)\n' >> "$wsb/progress.md"
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=ahead" ]; then pass "an unpushed snapshot reports ahead"; else fail "an unpushed snapshot reports ahead ($out)"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
printf 'note from A while behind\n' >> "$wsa/progress.md"
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=merged" ] && grep -q '^Task 3: complete' "$wsa/progress.md" && grep -q '^note from A while behind$' "$wsa/progress.md" && ! grep -qE '^<{7}' "$wsa/progress.md" && [ "$(git -C "$co_a" log -1 --format=%P hyperpowers/state | wc -w | tr -d ' ')" = 2 ]; then pass "behind with pending ledger edits ends merged with both sides' lines and two parents"; else fail "behind with pending ledger edits ends merged (rc=$rc: $out)"; fi
if [ -z "$(git -C "$co_a" status --porcelain -- plans/)" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "after a merge the checkout is clean and the ledger equals the merged blob"; else fail "after a merge the checkout is clean and the ledger equals the merged blob"; fi
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
# Two hosts append concurrently; the second host's fast-forward lands on
# the first host's merge, where S is not a prefix of the target.
printf 'walk A\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'walk B\n' >> "$wsb/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=merged" ] && [ "$(cat "$wsb/progress.md")" = "$(git -C "$co_b" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ]; then pass "the merging host's live ledger equals the merged blob"; else fail "the merging host's live ledger equals the merged blob (rc=$rc: $out)"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:plans/$(basename "$wsa")/progress.md")" ] && [ "$(grep -c '^walk A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^walk B$' "$wsa/progress.md")" -eq 1 ]; then pass "a fast-forward onto the other host's merge rewrites the ledger in place: tree order, each line once"; else fail "a fast-forward onto the other host's merge rewrites the ledger in place (rc=$rc: $out)"; fi
if [ "$(run_state "$PAIR_A" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ] && [ "$(run_state "$PAIR_B" sync docs/plan.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "both hosts stay up-to-date afterwards: no reorder commit"; else fail "both hosts stay up-to-date afterwards: no reorder commit"; fi
# A writer that lands between the rewrite's size check and its write on
# every attempt: the apply stops with the ref moved and the marker kept,
# nothing is snapshotted over it, and the next call finishes the apply with
# every raced line preserved.
printf 'walk2 A\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'walk2 B\n' >> "$wsb/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT=ledger-apply-before-rewrite bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
remote_tip=$(git -C "$co_a" rev-parse origin/hyperpowers/state)
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && [ -f "$co_a/.sync-applying" ] && [ "$(git -C "$co_a" rev-parse hyperpowers/state)" = "$remote_tip" ]; then pass "a writer racing the rewrite leaves the apply unfinished with the marker kept and nothing snapshotted over it"; else fail "a writer racing the rewrite leaves the apply unfinished with the marker kept and nothing snapshotted over it (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=ahead" ] && [ ! -f "$co_a/.sync-applying" ] && [ -z "$(git -C "$co_a" status --porcelain -- plans/)" ] && [ "$(grep -c '^raced the rewrite$' "$wsa/progress.md")" -eq 3 ] && [ "$(grep -c '^walk2 A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^walk2 B$' "$wsa/progress.md")" -eq 1 ] && [ "$(git -C "$co_a" rev-parse hyperpowers/state^)" = "$remote_tip" ]; then pass "the next call finishes the apply, keeps all three raced lines, and snapshots them on top of the target"; else fail "the next call finishes the apply, keeps all three raced lines, and snapshots them on top of the target (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'report edited on A\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
printf 'report edited on B\n' > "$wsb/task-1-report.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1)" = "status=diverged" ] && [ "$(printf '%s\n' "$out" | sed -n 2p)" = "merge=git -C $co_b merge origin/hyperpowers/state" ] && [ "$(cat "$wsb/task-1-report.md")" = "report edited on B" ]; then pass "conflicting report edits end diverged with the merge command and nothing changed"; else fail "conflicting report edits end diverged (rc=$rc: $out)"; fi
git -C "$co_b" -c user.name=t -c user.email=t@example.com merge -q -m "resolve" -X ours origin/hyperpowers/state >/dev/null 2>&1
if [ -z "$(git -C "$co_b" status --porcelain)" ] && [ "$(git -C "$co_b" log -1 --format=%P hyperpowers/state | wc -w | tr -d ' ')" = 2 ]; then pass "the human-run merge resolves the conflict (ours) and the ledger needs no markers"; else fail "the human-run merge resolves the conflict"; fi
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null

# A live writer during reconciliation: a ledger line appended while apply is
# held survives; a report that keeps changing ends busy.
printf 'Task 4: complete (commits 7777777..8888888, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
: > "$co_b/.sync-pause"
( cd "$PAIR_B" && HYPERPOWERS_TEST_PAUSE_AT=sync-before-apply bash "$SDD_STATE" sync docs/plan.md > "$TEST_ROOT/p7.sync.out" 2>/dev/null ) &
sync_pid=$!
n=0; while [ ! -e "$co_b/.sync-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
printf 'appended during sync\n' >> "$wsb/progress.md"
rm -f "$co_b/.sync-pause"
wait "$sync_pid"
if [ "$(cut -d' ' -f1 "$TEST_ROOT/p7.sync.out")" = "status=fast-forwarded" ] && grep -q '^Task 4: complete' "$wsb/progress.md" && grep -q '^appended during sync$' "$wsb/progress.md" && [ "$(grep -c '^Task 4: complete' "$wsb/progress.md")" -eq 1 ]; then pass "a ledger line appended while apply is held survives the fast-forward, and the remote line lands once"; else fail "a ledger line appended while apply is held survives the fast-forward ($(cat "$TEST_ROOT/p7.sync.out"))"; fi
# The held-apply line is still local: publish it so the next remote change is
# a plain fast-forward for this host.
settle_pair() { run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_A" sync docs/plan.md >/dev/null; }
settle_pair
# A write after the status check: the ledger is appended to, never replaced,
# so a line written at the last moment is kept too.
printf 'Task 4b: complete (commits bbbbbbb..ccccccc, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^concurrent write$' "$wsb/progress.md" && grep -q '^Task 4b: complete' "$wsb/progress.md"; then pass "a ledger line written during apply is kept beside the remote lines"; else fail "a ledger line written during apply is kept beside the remote lines (rc=$rc: $out)"; fi
settle_pair
printf 'Task 5: complete (commits 9999999..aaaaaaa, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-apply:plans/$(basename "$wsa")/task-1-report.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ]; then pass "a report that keeps changing across three attempts ends busy"; else fail "a report that keeps changing across three attempts ends busy (rc=$rc: $out)"; fi

# The busy attempts left local snapshots behind; stand in for the human
# partner discarding them, so the next remote change is a plain fast-forward.
git -C "$co_b" reset -q --hard origin/hyperpowers/state
# A second plan created on A appears on B, parent directory and all.
: > "$PAIR_A/docs/second.md"; git -C "$PAIR_A" add docs/second.md; git -C "$PAIR_A" commit -qm second; git -C "$PAIR_A" push -q origin main 2>/dev/null
ws2a=$(run_sdd_dir "$PAIR_A" docs/second.md); printf '# SDD ledger — plan: docs/second.md\n' > "$ws2a/progress.md"
run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=fast-forwarded" ] && [ -f "$co_b/plans/$(basename "$ws2a")/progress.md" ]; then pass "a plan added on the other host is materialized, parent directory included"; else fail "a plan added on the other host is materialized ($out)"; fi

# A crash after the ref moved: the next sync finishes the apply instead of
# snapshotting stale files as a revert.
printf 'Task 5b: complete (commits fffffff..1111111, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && ! grep -q '^Task 5b: complete' "$wsb/progress.md"; then pass "the crash seam stops after the ref moved, marker left"; else fail "the crash seam stops after the ref moved (rc=$rc)"; fi
tip_before=$(git -C "$co_b" rev-parse hyperpowers/state)
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=up-to-date" ] && grep -q '^Task 5b: complete' "$wsb/progress.md" && [ ! -f "$co_b/.sync-applying" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tip_before" ]; then pass "the next sync recovers the interrupted apply without a revert commit"; else fail "the next sync recovers the interrupted apply without a revert commit ($out)"; fi
printf 'Task 5c: complete (commits 9999999..aaaaaaa, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-ledger-apply bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ "$(grep -c '^Task 5c: complete' "$wsb/progress.md")" -eq 1 ]; then pass "the crash seam after the ledger apply leaves the line applied and the marker in place"; else fail "the crash seam after the ledger apply leaves the line applied and the marker in place (rc=$rc)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=up-to-date" ] && [ "$(grep -c '^Task 5c: complete' "$wsb/progress.md")" -eq 1 ] && [ ! -f "$co_b/.sync-applying" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "recovery after the ledger apply appends nothing twice"; else fail "recovery after the ledger apply appends nothing twice ($out)"; fi
# A link planted where the recovery must write a regular file: the marker
# stays, the human is told which repair clears it, and the plain sync that
# follows the repair completes the apply.
printf 'Task 7c: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
victim7c="$TEST_ROOT/victim-7c"; printf 'untouched\n' > "$victim7c"
rm -f "$wsb/progress.md"; ln -s "$victim7c" "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7c.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7c.err" && [ "$(cat "$victim7c")" = "untouched" ]; then pass "a post-ref containment failure keeps the marker, leaves the target untouched and names the repair"; else fail "a post-ref containment failure names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7c.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7c: complete' "$wsb/progress.md"; then pass "after the repair the next sync completes the apply and the ledger comes back from the branch"; else fail "after the repair the next sync completes the apply (rc=$rc: $out)"; fi
# The same link on the normal post-ref apply (no crash): the seam plants it
# after the ref moved, so recover_apply is not the one that meets it.
printf 'Task 7d: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-ref-link:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p7d.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -L "$wsb/progress.md" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7d.err"; then pass "a link met by the normal post-ref apply keeps the marker and names the repair"; else fail "a link met by the normal post-ref apply names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7d.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7d: complete' "$wsb/progress.md"; then pass "after that repair too the next sync completes the apply"; else fail "after that repair too the next sync completes the apply (rc=$rc: $out)"; fi
# A link at the workspace directory itself, with a report the target leaves
# unchanged: the apply has to recreate the directory, and the workspace must
# come back whole, or the next snapshot would record the report as deleted.
printf 'report\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7e: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7e="$TEST_ROOT/ws-7e-moved"; mv "$wsb" "$moved7e"; ln -s "$moved7e" "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7e.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7e.err" && [ "$(cat "$moved7e/task-1-report.md")" = report ]; then pass "a link at the workspace directory keeps the marker and names the repair"; else fail "a link at the workspace directory names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7e.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7e: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- "plans/$(basename "$wsb")")" ] && [ -n "$(git -C "$co_b" ls-tree --name-only refs/heads/hyperpowers/state -- "plans/$(basename "$wsb")/task-1-report.md")" ]; then pass "with the directory link removed the workspace comes back whole and no deletion is snapshotted"; else fail "with the directory link removed the workspace comes back whole (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A link where the apply removes a file: the delete walk names the repair.
rm -f "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
victim7f="$TEST_ROOT/victim-7f"; printf 'untouched\n' > "$victim7f"
rm -f "$wsb/task-1-report.md"; ln -s "$victim7f" "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7f.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7f.err" && [ "$(cat "$victim7f")" = untouched ]; then pass "a link where the apply removes a file keeps the marker, leaves the target untouched and names the repair"; else fail "a link where the apply removes a file names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7f.err"))"; fi
rm "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$wsb/task-1-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- "plans/$(basename "$wsb")")" ]; then pass "after that repair the delete walk completes and the tree is clean"; else fail "after that repair the delete walk completes (rc=$rc: $out)"; fi
# A link planted after the apply succeeded and before the re-walk: the
# re-walk names the repair, and the recovery that follows completes.
printf 'Task 7g: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-apply-link:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p7g.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -L "$wsb/progress.md" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7g.err"; then pass "a link met by the post-apply re-walk keeps the marker and names the repair"; else fail "a link met by the post-apply re-walk names the repair (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7g.err"))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7g: complete' "$wsb/progress.md"; then pass "after that repair too the recovery completes"; else fail "after that repair too the recovery completes (rc=$rc: $out)"; fi
# Two links met by one recovery, a workspace apart: the first apply creates
# the first workspace, publishes its ledger, and fails on the second
# workspace's link, leaving the first partial; the apply that finishes the
# recovery no longer creates that directory and must still complete it.
ws2b="$co_b/plans/$(basename "$ws2a")"
printf 'report\n' > "$wsa/task-1-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7h: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; printf 'Task 7h-second: complete (commits 1111111..2222222, review clean)\n' >> "$ws2a/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7h="$TEST_ROOT/ws-7h-moved"; mv "$wsb" "$moved7h"; ln -s "$moved7h" "$wsb"
victim7h="$TEST_ROOT/victim-7h"; printf 'untouched\n' > "$victim7h"; rm -f "$ws2b/progress.md"; ln -s "$victim7h" "$ws2b/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7h.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7h.err"; then pass "the first of two links is refused with the marker kept"; else fail "the first of two links is refused with the marker kept (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7h.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7h2.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7h2.err" && [ -f "$wsb/progress.md" ] && [ ! -e "$wsb/task-1-report.md" ] && [ "$(cat "$victim7h")" = untouched ]; then pass "the apply that created the first workspace is stopped by the second link, leaving it partial with the marker kept"; else fail "the apply that created the first workspace is stopped by the second link (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7h2.err"))"; fi
rm "$ws2b/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7h: complete' "$wsb/progress.md" && grep -q '^Task 7h-second: complete' "$ws2b/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ] && [ -n "$(git -C "$co_b" ls-tree --name-only refs/heads/hyperpowers/state -- "plans/$(basename "$wsb")/task-1-report.md")" ]; then pass "the apply that finishes the recovery completes the partial workspace and no deletion is snapshotted"; else fail "the apply that finishes the recovery completes the partial workspace (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A deletion-only apply met by a link at the workspace directory: the
# delete walk records the workspace too, so the recovery that follows the
# repair brings back the ledger and every other tracked file.
printf 'second report\n' > "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rm -f "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
moved7i="$TEST_ROOT/ws-7i-moved"; mv "$wsb" "$moved7i"; ln -s "$moved7i" "$wsb"; printf 'x\n' > "$moved7i/keep.restore.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7i.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'remove the link, leave' "$TEST_ROOT/p7i.err" && [ "$(cat "$moved7i/task-2-report.md")" = "second report" ] && [ -f "$moved7i/keep.restore.123" ]; then pass "a deletion-only apply met by a link at the workspace directory keeps the marker, names the repair, and sweeps nothing through the link"; else fail "a deletion-only apply met by a link at the workspace directory names the repair and sweeps nothing through the link (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7i.err"))"; fi
rm "$wsb"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7h: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ ! -e "$wsb/task-2-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "after the repair a deletion-only recovery brings the workspace back whole"; else fail "after the repair a deletion-only recovery brings the workspace back whole (rc=$rc: $out: $(git -C "$co_b" status --porcelain -- plans/ | tr '\n' '|'))"; fi
# A tracked file removed while the marker was down is put back by the
# recovery (the module's stance for a missing tracked file), and a file a
# writer creates right before the restore publishes it keeps the writer's
# bytes: the publish is one link(2), never a clobber.
printf 'Task 7j: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7j: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "a tracked file removed while the marker was down is put back by the recovery"; else fail "a tracked file removed while the marker was down is put back by the recovery (rc=$rc: $out)"; fi
printf 'Task 7k: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-restore:plans/$(basename "$wsb")/task-1-report.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7k: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = "concurrent write" ] && ! ls "$wsb"/*.restore.* >/dev/null 2>&1; then pass "a file a writer creates right before the restore publishes it keeps the writer's bytes"; else fail "a file a writer creates right before the restore publishes it keeps the writer's bytes (rc=$rc: $out: $(cat "$wsb/task-1-report.md" 2>/dev/null))"; fi
printf 'report\n' > "$wsb/task-1-report.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
# B pushed last, so A is behind: without this its snapshot below would be
# rejected silently and the remote finish would never reach B.
run_state "$PAIR_A" sync docs/plan.md >/dev/null
# A ledger a writer creates right before the restore publishes it is
# reconciled, never adopted: the branch's ledger stays intact and the sync
# stops with the marker, as for any ledger rewritten locally.
printf 'third report\n' > "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rm -f "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/progress.md"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-restore:plans/$(basename "$wsb")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ "$(cat "$wsb/progress.md")" = "concurrent write" ] && git -C "$co_b" show "refs/heads/hyperpowers/state:plans/$(basename "$wsb")/progress.md" | grep -q '^Task 7k: complete'; then pass "a writer's ledger met by the restore is reconciled, never adopted: the branch's ledger is intact and the sync stops"; else fail "a writer's ledger met by the restore is reconciled, never adopted (rc=$rc: $out: $(cat "$wsb/progress.md" 2>/dev/null | head -n 2 | tr '\n' '|'))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7k: complete' "$wsb/progress.md" && [ ! -e "$wsb/task-3-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "with the writer's ledger removed the restore publishes the branch's"; else fail "with the writer's ledger removed the restore publishes the branch's (rc=$rc: $out)"; fi
# A restored file keeps its tracked mode.
printf '#!/bin/sh\nexit 0\n' > "$wsa/run.sh"; chmod 755 "$wsa/run.sh"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'Task 7m: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/run.sh"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ -x "$wsb/run.sh" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "a restored file keeps its tracked mode"; else fail "a restored file keeps its tracked mode (rc=$rc: $out: $(ls -l "$wsb/run.sh" 2>&1))"; fi
# A crash between the restore's copy and its publish leaves the copy in
# the .restore sidecar, never inside a workspace: the next sync sweeps it,
# completes the restore, and nothing of it reaches the branch.
printf 'Task 7n: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=restore-after-copy bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ -n "$(ls -A "$co_b/.restore" 2>/dev/null)" ] && [ ! -e "$wsb/task-1-report.md" ] && ! ls "$wsb"/*.restore* >/dev/null 2>&1; then pass "the crash seam after the restore's copy leaves the copy in the sidecar and nothing in the workspace"; else fail "the crash seam after the restore's copy leaves the copy in the sidecar (rc=$rc: $(ls -A "$co_b/.restore" 2>&1 | tr '\n' '|'))"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$co_b/.restore" ] && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain)" ] && [ -z "$(git -C "$co_b" ls-tree -r --name-only refs/heads/hyperpowers/state | grep -F '.restore')" ]; then pass "the next sync sweeps the sidecar, completes the restore, and nothing of it reaches the branch"; else fail "the next sync sweeps the sidecar and completes the restore (rc=$rc: $out: $(git -C "$co_b" status --porcelain | tr '\n' '|'))"; fi
# A link at plans/ itself: the recovery refuses before any sweep or walk,
# and a matching file behind the link is untouched.
printf 'Task 7o: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
plansroot7o="$TEST_ROOT/plans-7o-moved"; mv "$co_b/plans" "$plansroot7o"; ln -s "$plansroot7o" "$co_b/plans"
printf 'x\n' > "$plansroot7o/$(basename "$wsb")/progress.md.new.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7o.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'plans is a symbolic link' "$TEST_ROOT/p7o.err" && [ -f "$plansroot7o/$(basename "$wsb")/progress.md.new.123" ]; then pass "a link at plans/ itself stops the recovery before any sweep, and the file behind it is untouched"; else fail "a link at plans/ itself stops the recovery before any sweep (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7o.err"))"; fi
rm "$co_b/plans"; mv "$plansroot7o" "$co_b/plans"; rm -f "$wsb/progress.md.new.123"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7o: complete' "$wsb/progress.md" && [ -z "$(git -C "$co_b" status --porcelain)" ]; then pass "with plans/ a real directory again the recovery completes"; else fail "with plans/ a real directory again the recovery completes (rc=$rc: $out)"; fi
# A ledger a writer recreated from scratch while the marker was down, in a
# deletion-only apply: the restore meets a live file it did not write, so
# it reconciles instead of leaving it for the next snapshot to publish over
# the branch's ledger.
printf 'fourth report\n' > "$wsa/task-4-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rm -f "$wsa/task-4-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/progress.md"; printf 'concurrent write\n' > "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ "$(cat "$wsb/progress.md")" = "concurrent write" ] && git -C "$co_b" show "refs/heads/hyperpowers/state:plans/$(basename "$wsb")/progress.md" | grep -q '^Task 7o: complete'; then pass "a ledger recreated under a deletion-only apply is reconciled, and the branch's is intact"; else fail "a ledger recreated under a deletion-only apply is reconciled, and the branch's is intact (rc=$rc: $out: $(head -n 2 "$wsb/progress.md" 2>/dev/null | tr '\n' '|'))"; fi
rm -f "$wsb/progress.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7o: complete' "$wsb/progress.md" && [ ! -e "$wsb/task-4-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain)" ]; then pass "with that ledger removed the deletion-only recovery publishes the branch's"; else fail "with that ledger removed the deletion-only recovery publishes the branch's (rc=$rc: $out)"; fi
# A link at the .restore sidecar: nothing is swept or staged through it,
# and the directory behind it stays empty.
printf 'Task 7q: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
mkdir -p "$TEST_ROOT/victim-restore"; ln -s "$TEST_ROOT/victim-restore" "$co_b/.restore"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>"$TEST_ROOT/p7q.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q '\.restore is a symbolic link' "$TEST_ROOT/p7q.err" && [ -z "$(ls -A "$TEST_ROOT/victim-restore")" ]; then pass "a link at the .restore sidecar stops the sync and nothing is written through it"; else fail "a link at the .restore sidecar stops the sync and nothing is written through it (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7q.err"): $(ls -A "$TEST_ROOT/victim-restore" | tr '\n' '|'))"; fi
rm "$co_b/.restore"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7q: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain)" ]; then pass "with the link removed the restore completes"; else fail "with the link removed the restore completes (rc=$rc: $out)"; fi
# The same link planted in the window recover_apply cannot cover: the whole
# apply runs between its check at the top of the locked section and the
# staging mkdir, and mkdir -p through a link to a directory keeps the link,
# so the copy would land outside the checkout.
printf 'Task 7r: complete (commits 1111111..2222222, review clean)\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
rm -f "$wsb/task-1-report.md"
mkdir -p "$TEST_ROOT/victim-restore-write"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-link-restore:$TEST_ROOT/victim-restore-write" bash "$SDD_STATE" sync docs/plan.md 2>"$TEST_ROOT/p7r.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && grep -q 'refusing to stage a restore copy' "$TEST_ROOT/p7r.err" && [ -z "$(ls -A "$TEST_ROOT/victim-restore-write")" ]; then pass "a link planted at the .restore sidecar during the apply stops it before the copy, and nothing is staged through it"; else fail "a link planted at the .restore sidecar during the apply stops it before the copy (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p7r.err"): $(ls -A "$TEST_ROOT/victim-restore-write" | tr '\n' '|'))"; fi
rm "$co_b/.restore"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 7r: complete' "$wsb/progress.md" && [ "$(cat "$wsb/task-1-report.md")" = report ] && [ -z "$(git -C "$co_b" status --porcelain)" ]; then pass "with that link removed the restore completes too"; else fail "with that link removed the restore completes too (rc=$rc: $out)"; fi

# A remote finish racing a local writer: refused, nothing changed. The seam
# writes after the pending check and right before the rename.
printf 'Task 6: complete (commits ddddddd..eeeeeee, review clean)\n' >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
run_state "$PAIR_A" finish docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-before-delete:plans/$(basename "$wsa")/progress.md" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=remote-finished" ] && grep -q "plans=$(basename "$wsa")" < <(printf '%s\n' "$out") && [ -f "$wsb/progress.md" ] && grep -q '^concurrent write$' "$wsb/progress.md" && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" != "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "a line written after the check and before the rename still makes the remote finish refuse, ledger and ref intact"; else fail "a remote finish racing a local ledger write is refused (rc=$rc: $out)"; fi
if ( cd "$co_b" && printf 'late\n' >> "plans/.removing-probe-0/progress.md" ) 2>/dev/null; then fail "a write to a renamed-away path fails loudly"; else pass "a write to a renamed-away path fails loudly (ENOENT), never silently"; fi
run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=diverged" ]; then pass "after snapshotting the local line the race is an ordinary divergence"; else fail "after snapshotting the local line the race is an ordinary divergence (rc=$rc: $out)"; fi
git -C "$co_b" merge --abort >/dev/null 2>&1 || true
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); run_state "$PAIR_A" sync docs/plan.md >/dev/null

# Offline outcomes and the explicit override.
off="$TEST_ROOT/hostA/p7-off"; git clone -q --single-branch -b main "$PAIR_REMOTE" "$off" 2>/dev/null
git -C "$off" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$off" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline-no-state" ]; then pass "a fresh clone that cannot fetch reports offline-no-state"; else fail "a fresh clone that cannot fetch reports offline-no-state (rc=$rc: $out)"; fi
if run_sdd_dir "$off" docs/plan.md >/dev/null 2>&1; then fail "sdd-dir refuses to invent a dossier on that host"; else pass "sdd-dir refuses to invent a dossier on that host"; fi
off2="$TEST_ROOT/hostA/p7-off2"; git clone -q "$PAIR_REMOTE" "$off2" 2>/dev/null
git -C "$off2" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$off2" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline" ] && [ -e "$STATE_ROOT/$(state_key "$off2")/.git" ] && [ -n "$(git -C "$off2" rev-parse -q --verify refs/heads/hyperpowers/state 2>/dev/null)" ]; then pass "a default clone that cannot fetch still has the branch as a remote-tracking ref: offline, checkout built from it"; else fail "a default clone that cannot fetch still has the branch as a remote-tracking ref (rc=$rc: $out)"; fi
out=$(run_state "$off" sync docs/plan.md --assume-absent); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=assumed-absent" ] && [ -f "$STATE_ROOT/$(state_key "$off").fetched" ] && [ -e "$STATE_ROOT/$(state_key "$off")/.git" ]; then pass "--assume-absent writes the stamp and creates the orphan"; else fail "--assume-absent writes the stamp and creates the orphan (rc=$rc: $out)"; fi
if [ "$(head -n 1 "$STATE_ROOT/$(state_key "$off").fetched")" = "origin hyperpowers/state $(fp "$off")" ]; then pass "--assume-absent stamps the remote, branch and URL fingerprint"; else fail "--assume-absent stamps the remote, branch and URL fingerprint (got: $(cat "$STATE_ROOT/$(state_key "$off").fetched" 2>/dev/null))"; fi
out=$(run_state "$off" sync docs/plan.md); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=offline" ]; then pass "a later failed fetch with a local branch reports offline"; else fail "a later failed fetch with a local branch reports offline (rc=$rc: $out)"; fi
norem="$TEST_ROOT/norem"; make_repo "$norem"; mkdir -p "$norem/docs"; : > "$norem/docs/plan.md"; git -C "$norem" add docs; git -C "$norem" commit -qm plan
out=$(run_state "$norem" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=no-remote" ]; then pass "no remote reports no-remote"; else fail "no remote reports no-remote (rc=$rc: $out)"; fi
nr="$TEST_ROOT/nr"; make_repo "$nr"; mkdir -p "$nr/docs"; : > "$nr/docs/plan.md"
out=$(run_state "$nr" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=no-remote" ] && [ ! -e "$STATE_ROOT/$(state_key "$nr").fetched" ]; then pass "a no-remote sync leaves no stamp"; else fail "a no-remote sync leaves no stamp (rc=$rc: $out)"; fi
# The stamp governs creation only: a no-remote sync created a local branch
# here, which is continued, and a remote added later is reconciled by the
# next sync. The creation path is reached only when neither the checkout
# nor the local branch exists, so the fixture removes both before asking.
git -C "$nr" worktree remove --force "$STATE_ROOT/$(state_key "$nr")" >/dev/null 2>&1 || rm -rf "${STATE_ROOT:?}/$(state_key "$nr")"; git -C "$nr" worktree prune; git -C "$nr" branch -D hyperpowers/state >/dev/null 2>&1
git -C "$nr" remote add origin "$TEST_ROOT/nowhere.git"
err=$(ensure "$nr" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync' && [ ! -d "$STATE_ROOT/$(state_key "$nr")" ]; then pass "with its branch and checkout gone, a repository that gained a remote after a no-remote sync asks for a sync before any branch is created"; else fail "a repository that gained a remote after a no-remote sync asks for a sync (rc=$rc: $err)"; fi
# The realistic transition keeps the local branch: a remote that already
# holds another dossier is reconciled, never silently replaced or invented.
nr2="$TEST_ROOT/nr2"; make_repo "$nr2"; mkdir -p "$nr2/docs"; : > "$nr2/docs/plan.md"
run_state "$nr2" sync docs/plan.md >/dev/null; wsnr2=$(run_sdd_dir "$nr2" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsnr2/progress.md"; run_state "$nr2" snapshot docs/plan.md >/dev/null
git -C "$nr2" remote add origin "$PAIR_REMOTE"
out=$(run_state "$nr2" sync docs/plan.md 2>/dev/null); rc=$?
if [ "${out%% *}" = "status=diverged" ] && [ -f "$wsnr2/progress.md" ] && grep -q '^Task 1: complete' "$wsnr2/progress.md"; then pass "a remote gained after a no-remote sync is reconciled by the next sync (diverged, nothing invented, the local ledger kept)"; else fail "a remote gained after a no-remote sync is reconciled by the next sync (rc=$rc: $out)"; fi
ons="$TEST_ROOT/ons"; make_repo "$ons"; mkdir -p "$ons/docs"; : > "$ons/docs/plan.md"; git -C "$ons" remote add origin "$TEST_ROOT/nowhere.git"
out=$(run_state "$ons" sync docs/plan.md 2>/dev/null); rc=$?
if [ "${out%% *}" = "status=offline-no-state" ] && [ ! -e "$STATE_ROOT/$(state_key "$ons").fetched" ]; then pass "an offline sync with no state branch leaves no stamp"; else fail "an offline sync with no state branch leaves no stamp (rc=$rc: $out)"; fi
err=$(ensure "$ons" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'needs-sync'; then pass "after an offline sync creation still asks for a sync"; else fail "after an offline sync creation still asks for a sync (rc=$rc: $err)"; fi
if [ "$(run_state "$rp" sync docs/plan.md 2>/dev/null)" = "status=plain" ]; then pass "sync under the plain backend reports plain"; else fail "sync under the plain backend reports plain"; fi

# Cross-repository: sync resolves the plan's repository, not the cwd's.
other_cwd="$TEST_ROOT/other-cwd"; make_repo "$other_cwd"
out=$(cd "$other_cwd" && bash "$SDD_STATE" sync "$PAIR_A/docs/plan.md"); rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$STATE_ROOT/$(state_key "$other_cwd")" ]; then pass "sync from another repository's cwd touches only the plan repository"; else fail "sync from another repository's cwd touches only the plan repository (rc=$rc: $out)"; fi
# The remaining checks use docs/second.md, present on both hosts.
ws2b="$co_b/plans/$(basename "$ws2a")"
run_state "$PAIR_A" sync docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/second.md >/dev/null
# The race test above left B's snapshot of its local line unmerged (an
# ordinary divergence by design); the human partner discards it here so the
# checks below start from a host that is level with the remote.
git -C "$co_b" merge --abort >/dev/null 2>&1 || true
git -C "$co_b" reset -q --hard origin/hyperpowers/state
# A branch at the state name without the sentinel is foreign.
foreign=$(git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(git -C "$PAIR_A" hash-object -t tree /dev/null)" -m foreign)
git -C "$PAIR_A" push -qf origin "$foreign:refs/heads/hyperpowers/state" 2>/dev/null
tip_b=$(git -C "$co_b" rev-parse hyperpowers/state)
out=$(run_state "$PAIR_B" sync docs/second.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out%% *}" = "status=foreign" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tip_b" ] && [ -f "$ws2b/progress.md" ]; then pass "a remote branch without the sentinel is foreign: nothing reconciled, ref and files untouched"; else fail "a remote branch without the sentinel is foreign: nothing reconciled, ref and files untouched (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -qf origin hyperpowers/state 2>/dev/null
if [ "$(run_state "$PAIR_B" sync docs/second.md | cut -d' ' -f1)" = "status=up-to-date" ]; then pass "with the real branch restored, sync resumes"; else fail "with the real branch restored, sync resumes"; fi
# A deletion the target asks for that cannot be done is an error, never "applied".
printf 'report two\n' > "$ws2a/task-2-report.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/second.md >/dev/null
rm -f "$ws2a/task-2-report.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
chmod 555 "$ws2b"
out=$(run_state "$PAIR_B" sync docs/second.md 2>/dev/null); rc=$?
chmod 755 "$ws2b"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -f "$co_b/.sync-applying" ] && [ -f "$ws2b/task-2-report.md" ]; then pass "a deletion the target asks for that fails is an error with the marker kept, never reported as applied"; else fail "a deletion the target asks for that fails is an error with the marker kept, never reported as applied (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_B" sync docs/second.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -e "$ws2b/task-2-report.md" ] && [ -z "$(git -C "$co_b" status --porcelain -- plans/)" ]; then pass "once the directory is writable the next sync finishes the deletion"; else fail "once the directory is writable the next sync finishes the deletion (rc=$rc: $out)"; fi
# A writer that lands between the extension append and the in-place
# overwrite: the line survives and the apply succeeds.
printf 'ov A\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null
printf 'ov B\n' >> "$ws2b/progress.md"; run_state "$PAIR_B" snapshot docs/second.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/second.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_A" && HYPERPOWERS_TEST_WRITER_AT=ledger-apply-before-overwrite bash "$SDD_STATE" sync docs/second.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(grep -c '^raced the overwrite$' "$ws2a/progress.md")" -eq 1 ] && [ "$(grep -c '^ov A$' "$ws2a/progress.md")" -eq 1 ] && [ "$(grep -c '^ov B$' "$ws2a/progress.md")" -eq 1 ]; then pass "a line appended between the extension append and the overwrite survives the rewrite"; else fail "a line appended between the extension append and the overwrite survives the rewrite (rc=$rc: $out)"; fi
run_state "$PAIR_A" sync docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/second.md >/dev/null
# The marker is a barrier for claim, prune and finish.
printf 'Task 9: complete (commits fffffff..0000000, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" claim docs/second.md 9 --session s-claim); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=done task=9" ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 9: complete' "$ws2b/progress.md"; then pass "claim recovers an interrupted apply before it reads the ledger"; else fail "claim recovers an interrupted apply before it reads the ledger (rc=$rc: $out)"; fi
printf 'Task 10: complete (commits 1212121..3434343, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" prune --repo "$PAIR_B" --apply); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pruned" ] && [ ! -f "$co_b/.sync-applying" ] && grep -q '^Task 10: complete' "$ws2b/progress.md"; then pass "prune --apply recovers an interrupted apply before it selects"; else fail "prune --apply recovers an interrupted apply before it selects (rc=$rc: $out)"; fi
printf 'Task 11: complete (commits 5656565..7878787, review clean)\n' >> "$ws2a/progress.md"; run_state "$PAIR_A" snapshot docs/second.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/second.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" finish docs/second.md --force); rc=$?
last_b=$(printf '%s' "$out" | sed -n 's/.* last=\([0-9a-f]*\).*/\1/p')
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -f "$co_b/.sync-applying" ] && git -C "$co_b" show "$last_b:plans/$(basename "$ws2a")/progress.md" 2>/dev/null | grep -q '^Task 11: complete'; then pass "finish recovers an interrupted apply before it reads claims or snapshots"; else fail "finish recovers an interrupted apply before it reads claims or snapshots (rc=$rc: $out)"; fi
# A marker that cannot be trusted fails closed and is named.
printf 'garbage\n' > "$co_b/.sync-applying"
out=$(run_state "$PAIR_B" sync docs/second.md 2>"$TEST_ROOT/marker.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'not a valid sync marker' "$TEST_ROOT/marker.err" && [ -f "$co_b/.sync-applying" ]; then pass "a malformed marker fails closed and is named"; else fail "a malformed marker fails closed and is named (rc=$rc: $out)"; fi
rm -f "$co_b/.sync-applying"
tipb=$(git -C "$co_b" rev-parse hyperpowers/state); prev=$(git -C "$co_b" rev-parse hyperpowers/state^)
printf '%s %s\n' "$prev" "$prev" > "$co_b/.sync-applying"
out=$(run_state "$PAIR_B" sync docs/second.md 2>"$TEST_ROOT/marker2.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'has moved from its target' "$TEST_ROOT/marker2.err" && [ -f "$co_b/.sync-applying" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tipb" ]; then pass "a marker whose target the branch has left fails closed and is named"; else fail "a marker whose target the branch has left fails closed and is named (rc=$rc: $out)"; fi
rm -f "$co_b/.sync-applying"
# A fresh pair for the backstop checks.
make_pair p8
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_a="$STATE_ROOT/$(state_key "$PAIR_A")"; co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; wsb="$co_b/plans/$(basename "$wsa")"; lpath="plans/$(basename "$wsa")/progress.md"
# A remote-tracking ref swapped after the fetch is ignored.
foreign=$(git -C "$PAIR_B" -c user.name=t -c user.email=t@example.com commit-tree "$(git -C "$PAIR_B" hash-object -t tree /dev/null)" -m foreign)
printf 'pinned line\n' >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_WRITER_AT="sync-after-pin:$foreign" bash "$SDD_STATE" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$(git -C "$PAIR_A" rev-parse hyperpowers/state)" ] && grep -q '^pinned line$' "$wsb/progress.md"; then pass "a remote-tracking ref swapped after the fetch is ignored: the pinned, validated sha is what gets reconciled"; else fail "a remote-tracking ref swapped after the fetch is ignored: the pinned, validated sha is what gets reconciled (rc=$rc: $out)"; fi
run_state "$PAIR_B" sync docs/plan.md >/dev/null
# Each round leaves A positioned for a fast-forward onto B's merge, where
# S is not a prefix of the target and the ledger is rewritten.
reorder_round() { printf '%s\n' "$1" >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; printf '%s\n' "$2" >> "$wsb/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null; }
reorder_round 'j1 A' 'j1 B'
( cd "$PAIR_A" && HYPERPOWERS_TEST_CRASH_AT=rewrite-after-journal bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_a/.rewrite/$(basename "$wsa").journal" ] && [ -f "$co_a/.sync-applying" ]; then pass "the crash seam after the journal leaves the journal and the marker"; else fail "the crash seam after the journal leaves the journal and the marker (rc=$rc)"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:$lpath")" ] && [ ! -e "$co_a/.rewrite/$(basename "$wsa").journal" ] && [ ! -f "$co_a/.sync-applying" ] && [ "$(grep -c '^j1 A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^j1 B$' "$wsa/progress.md")" -eq 1 ]; then pass "recovery finishes a rewrite interrupted before its first write, byte-exact"; else fail "recovery finishes a rewrite interrupted before its first write, byte-exact (rc=$rc: $out)"; fi
reorder_round 'j2 A' 'j2 B'
( cd "$PAIR_A" && HYPERPOWERS_TEST_CRASH_AT=rewrite-after-extend bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
out=$(run_state "$PAIR_A" sync docs/plan.md); rc2=$?
if [ "$rc" -eq 99 ] && [ "$rc2" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ "$(cat "$wsa/progress.md")" = "$(git -C "$co_a" show "hyperpowers/state:$lpath")" ] && [ ! -e "$co_a/.rewrite/$(basename "$wsa").journal" ] && [ "$(grep -c '^j2 A$' "$wsa/progress.md")" -eq 1 ] && [ "$(grep -c '^j2 B$' "$wsa/progress.md")" -eq 1 ]; then pass "recovery finishes a rewrite interrupted between its two writes without duplicating bytes"; else fail "recovery finishes a rewrite interrupted between its two writes without duplicating bytes (rc=$rc/$rc2: $out)"; fi
# A crash after the marker but before the copies go, and one after they went: both recover forward.
: > "$PAIR_A/docs/fin.md"; git -C "$PAIR_A" add docs/fin.md; git -C "$PAIR_A" commit -qm fin; git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
wsf=$(run_sdd_dir "$PAIR_A" docs/fin.md); printf '# SDD ledger — plan: docs/fin.md\n' > "$wsf/progress.md"; run_state "$PAIR_A" snapshot docs/fin.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; wsfb="$co_b/plans/$(basename "$wsf")"
run_state "$PAIR_A" finish docs/fin.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-marker bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ ! -d "$wsfb" ] && ls -d "$co_b"/plans/.removing-* >/dev/null 2>&1 && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" != "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "the crash seam after the marker leaves the copy renamed aside, the marker down and the ref at S"; else fail "the crash seam after the marker leaves the copy renamed aside, the marker down and the ref at S (rc=$rc)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -d "$wsfb" ] && ! ls -d "$co_b"/plans/.removing-* >/dev/null 2>&1 && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "recovery moves the ref forward, drops the verified copy, and the remote finish holds"; else fail "recovery moves the ref forward, drops the verified copy, and the remote finish holds (rc=$rc: $out)"; fi
: > "$PAIR_A/docs/fin2.md"; git -C "$PAIR_A" add docs/fin2.md; git -C "$PAIR_A" commit -qm fin2; git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
wsf2=$(run_sdd_dir "$PAIR_A" docs/fin2.md); printf '# SDD ledger — plan: docs/fin2.md\n' > "$wsf2/progress.md"; run_state "$PAIR_A" snapshot docs/fin2.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; wsf2b="$co_b/plans/$(basename "$wsf2")"
run_state "$PAIR_A" finish docs/fin2.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-discard bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && [ ! -d "$wsf2b" ] && ! ls -d "$co_b"/plans/.removing-* >/dev/null 2>&1 && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" != "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "the crash seam after the discard leaves the copy gone, the marker down and the ref at S"; else fail "the crash seam after the discard leaves the copy gone, the marker down and the ref at S (rc=$rc)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -d "$wsf2b" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$(git -C "$co_b" rev-parse origin/hyperpowers/state)" ]; then pass "recovery after the discard moves the ref forward and the remote finish holds"; else fail "recovery after the discard moves the ref forward and the remote finish holds (rc=$rc: $out)"; fi
echo ""
echo ""
echo "=== verify ==="
make_pair p9
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
base_a=$(git -C "$PAIR_A" rev-parse HEAD)
printf 'work\n' > "$PAIR_A/work.txt"; git -C "$PAIR_A" add work.txt; git -C "$PAIR_A" commit -qm "task 1"
head_a=$(git -C "$PAIR_A" rev-parse HEAD)
root_a=$(git -C "$PAIR_A" rev-list --max-parents=0 HEAD | sort | head -n 1)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$PAIR_A" rev-parse --short=7 "$base_a")" "$(git -C "$PAIR_A" rev-parse --short=7 "$head_a")" > "$wsa/progress.md"
if [ "$(run_state "$PAIR_A" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes where the commits live"; else fail "verify passes where the commits live"; fi
printf 'handoff: code root=%s main@%s at 2026-10-20T00:00:00Z from hostA\n' "$root_a" "$head_a" >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=created" ]; then pass "the second host receives the dossier"; else fail "the second host receives the dossier ($out)"; fi
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=code-missing missing=$(git -C "$PAIR_A" rev-parse --short=7 "$head_a") branch=main" ]; then pass "verify names the missing head commit once and the branch before the pull"; else fail "verify names the missing head commit once and the branch before the pull (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes after the pull"; else fail "verify passes after the pull"; fi
# A range whose base is missing fails too: a shallow clone of depth 1 has
# the head but not the base.
shallow="$TEST_ROOT/hostB/p9-shallow"
git clone -q --depth 1 "file://$PAIR_REMOTE" "$shallow" 2>/dev/null
git -C "$shallow" config user.name t; git -C "$shallow" config user.email t@example.com
run_state "$shallow" sync docs/plan.md >/dev/null
out=$(run_state "$shallow" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% *}" = "status=code-missing" ] && grep -q "missing=$(git -C "$PAIR_A" rev-parse --short=7 "$base_a")" < <(printf '%s\n' "$out"); then pass "a shallow checkout without the range's base is code-missing, not wrong-repo"; else fail "a shallow checkout without the range's base is code-missing, not wrong-repo (rc=$rc: $out)"; fi
if [ -e "$STATE_ROOT/$(state_key "$shallow")/.git" ]; then pass "a single-branch depth-1 clone gets the branch backend, not the plain fallback"; else fail "a single-branch depth-1 clone gets the branch backend, not the plain fallback"; fi
unrelated="$TEST_ROOT/unrelated"; make_repo "$unrelated"
out=$(cd "$unrelated" && bash "$SDD_STATE" verify "$PAIR_B/docs/plan.md"); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=${root_a:0:7} repo=code" ]; then pass "verify from an unrelated repository reports wrong-repo"; else fail "verify from an unrelated repository reports wrong-repo (rc=$rc: $out)"; fi
# The plan repository is checked when a handoff: plan line exists.
wsb="$STATE_ROOT/$(state_key "$PAIR_B")/plans/$(basename "$wsa")"
git -C "$PAIR_A" commit -q --allow-empty -m "plan v2"
printf 'handoff: plan root=%s main@%s\n' "$root_a" "$(git -C "$PAIR_A" rev-parse HEAD)" >> "$wsb/progress.md"
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=plan-stale sha=$(git -C "$PAIR_A" rev-parse --short=7 HEAD) branch=main" ]; then pass "a destination holding an older plan is plan-stale"; else fail "a destination holding an older plan is plan-stale (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "verify passes once the plan repository has the recorded commit"; else fail "verify passes once the plan repository has the recorded commit"; fi
printf 'handoff: plan root=0000000000000000000000000000000000000001 main@%s\n' "$(git -C "$PAIR_A" rev-parse HEAD)" >> "$wsb/progress.md"
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=0000000 repo=plan" ]; then pass "a plan repository with another root is wrong-repo"; else fail "a plan repository with another root is wrong-repo (rc=$rc: $out)"; fi
# A completion line that arrived with the last fetch but was never applied
# (sync crashed after the ref moved): verify finishes the apply first.
printf 'two\n' > "$PAIR_A/two.txt"; git -C "$PAIR_A" add two.txt; git -C "$PAIR_A" commit -qm "task 2"
head2_a=$(git -C "$PAIR_A" rev-parse HEAD)
printf 'Task 2: complete (commits %s..%s, review clean)\n' "$(git -C "$PAIR_A" rev-parse --short=7 "$base_a")" "$(git -C "$PAIR_A" rev-parse --short=7 "$head2_a")" >> "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 )
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=code-missing missing=$(git -C "$PAIR_A" rev-parse --short=7 "$head2_a") branch=main" ] && [ ! -f "$co_b/.sync-applying" ]; then pass "verify finishes an interrupted sync before it reads the ledger and sees the arrived range"; else fail "verify finishes an interrupted sync before it reads the ledger and sees the arrived range (rc=$rc: $out)"; fi
# A plain-backend host: the dossier is on the branch only until verify
# materializes it.
plainhost="$TEST_ROOT/hostB/p9-plain"; git clone -q "$PAIR_REMOTE" "$plainhost" 2>/dev/null
git -C "$plainhost" config user.name t; git -C "$plainhost" config user.email t@example.com
( cd "$plainhost" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 )
out=$(run_state "$plainhost" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=code-missing missing=$(git -C "$PAIR_A" rev-parse --short=7 "$head2_a") branch=main" ]; then pass "under the plain backend verify materializes the dossier before judging it, and checks its ranges"; else fail "under the plain backend verify materializes the dossier before judging it, and checks its ranges (rc=$rc: $out)"; fi

echo ""
echo "=== handoff ==="
make_pair p10
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf 'work\n' > "$PAIR_A/work.txt"; git -C "$PAIR_A" add work.txt; git -C "$PAIR_A" commit -qm "task 1"
head_a=$(git -C "$PAIR_A" rev-parse HEAD)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$PAIR_A" rev-parse --short=7 HEAD~1)" "$(git -C "$PAIR_A" rev-parse --short=7 HEAD)" > "$wsa/progress.md"
: > "$PAIR_A/docs/untracked.md"
out=$(run_state "$PAIR_A" handoff docs/untracked.md); rc=$?
if [ "$rc" -eq 8 ] && [ "$out" = "status=plan-not-committed file=docs/untracked.md" ]; then pass "handoff refuses an untracked plan"; else fail "handoff refuses an untracked plan (rc=$rc: $out)"; fi
rm -f "$PAIR_A/docs/untracked.md"
printf 'edit\n' >> "$PAIR_A/docs/plan.md"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 8 ]; then pass "handoff refuses a modified plan"; else fail "handoff refuses a modified plan (rc=$rc: $out)"; fi
out=$(run_state "$PAIR_A" handoff docs/plan.md --plan-untracked-ok); rc=$?
if [ "$rc" -eq 10 ] && [ "${out%% *}" = "status=code-dirty" ]; then pass "--plan-untracked-ok waives the plan check and the dirty tree is caught next"; else fail "--plan-untracked-ok waives the plan check and the dirty tree is caught next (rc=$rc: $out)"; fi
git -C "$PAIR_A" checkout -q -- docs/plan.md
: > "$PAIR_A/stray.txt"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 10 ] && [ "$out" = "status=code-dirty paths=stray.txt" ]; then pass "an untracked file is a dirty code tree"; else fail "an untracked file is a dirty code tree (rc=$rc: $out)"; fi
printf 'staged\n' > "$PAIR_A/staged.txt"; git -C "$PAIR_A" add staged.txt
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 10 ] && [ "$out" = "status=code-dirty paths=staged.txt,stray.txt" ]; then pass "a staged change is a dirty code tree, listed with the untracked file"; else fail "a staged change is a dirty code tree, listed with the untracked file (rc=$rc: $out)"; fi
git -C "$PAIR_A" reset -q staged.txt; rm -f "$PAIR_A/staged.txt"
out=$(run_state "$PAIR_A" handoff docs/plan.md --code-dirty-ok); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=snapshot" ]; then pass "--code-dirty-ok waives the dirty check"; else fail "--code-dirty-ok waives the dirty check (rc=$rc: $out)"; fi
rm -f "$PAIR_A/stray.txt"
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
case "$out" in "status=snapshot sha="???????" code=main@"???????" push=origin/hyperpowers/state") pass "handoff without --push snapshots and names the push target" ;; *) fail "handoff without --push snapshots and names the push target (rc=$rc: $out)" ;; esac
if grep -Eq "^handoff: code root=[0-9a-f]{40} main@$head_a at [0-9TZ:-]+ from " "$wsa/progress.md"; then pass "the ledger records the code repository's root, branch and head"; else fail "the ledger records the code repository's root, branch and head"; fi
if ! git -C "$PAIR_REMOTE" rev-parse -q --verify refs/heads/hyperpowers/state >/dev/null 2>&1; then pass "nothing was pushed without --push"; else fail "nothing was pushed without --push"; fi

# The first push is scanned over the whole history, root commit included.
git -C "$PAIR_A" config hyperpowers.prePushScan '! grep -q SECRETTOKEN'
printf 'SECRETTOKEN\n' > "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
rm -f "$wsa/task-2-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 5 ] && [ "$out" = "status=scan-failed reason=scanner" ] && ! git -C "$PAIR_REMOTE" rev-parse -q --verify refs/heads/hyperpowers/state >/dev/null 2>&1; then pass "content added and deleted before the first push still blocks it"; else fail "content added and deleted before the first push still blocks it (rc=$rc: $out)"; fi
git -C "$PAIR_A" config hyperpowers.prePushScan 'grep -q "^+hyperpowers-state 1$"'
out=$(run_state "$PAIR_A" handoff docs/plan.md --push); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pushed" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)" = "$(git -C "$PAIR_A" rev-parse hyperpowers/state)" ]; then pass "a passing scanner lets --push publish the state branch, and the first push's scan includes the root commit"; else fail "a passing scanner lets --push publish the state branch, and the first push's scan includes the root commit (rc=$rc: $out)"; fi
git -C "$PAIR_A" config hyperpowers.prePushScan '! grep -q SECRETTOKEN'
printf 'SECRETTOKEN again\n' > "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
rm -f "$wsa/task-3-report.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 5 ]; then pass "content added and deleted since the last push blocks a later push"; else fail "content added and deleted since the last push blocks a later push (rc=$rc: $out)"; fi
# A side branch that added and deleted a secret before being merged: the
# merge's net diff is clean, the side commits are what the push publishes.
co_a7="$STATE_ROOT/$(state_key "$PAIR_A")"
# The earlier SECRETTOKEN commits are still unpushed and in range, so this check
# scans for a token only the side branch carries.
git -C "$PAIR_A" config hyperpowers.prePushScan '! grep -q SIDETOKEN'
git -C "$co_a7" checkout -q -b side
printf 'SIDETOKEN on the side\n' > "$co_a7/plans/$(basename "$wsa")/task-11-report.md"
git -C "$co_a7" add -A -- "plans/$(basename "$wsa")"; git -C "$co_a7" -c user.name=t -c user.email=t@example.com commit -qm "side adds"
git -C "$co_a7" rm -q -- "plans/$(basename "$wsa")/task-11-report.md"; git -C "$co_a7" -c user.name=t -c user.email=t@example.com commit -qm "side removes"
git -C "$co_a7" checkout -q hyperpowers/state
git -C "$co_a7" -c user.name=t -c user.email=t@example.com merge -q --no-ff -m "merge side" side; git -C "$co_a7" branch -q -D side
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 5 ] && [ "$out" = "status=scan-failed reason=scanner" ]; then pass "a secret added and deleted on a merged side branch still blocks the push"; else fail "a secret added and deleted on a merged side branch still blocks the push (rc=$rc: $out)"; fi
git -C "$PAIR_A" config --unset hyperpowers.prePushScan

# A snapshot queued during a hand-off lands after the push; the push carries
# exactly the scanned commit.
co_a7="$STATE_ROOT/$(state_key "$PAIR_A")"
git -C "$PAIR_A" config hyperpowers.prePushScan 'cat > /dev/null'
: > "$co_a7/.handoff-pause"
( cd "$PAIR_A" && HYPERPOWERS_TEST_PAUSE_AT=handoff-after-scan bash "$SDD_STATE" handoff docs/plan.md --push > "$TEST_ROOT/p7.handoff" 2>/dev/null ) &
n=0; while [ ! -e "$co_a7/.handoff-paused" ] && [ "$n" -lt 300 ]; do sleep 0.1; n=$((n + 1)); done
printf 'queued\n' > "$wsa/task-9-report.md"
( run_state "$PAIR_A" snapshot docs/plan.md > "$TEST_ROOT/p7.snap" 2>/dev/null ) &
sleep 1; rm -f "$co_a7/.handoff-pause"; wait
pushed_sha=$(sed -n 's/^status=pushed sha=\([0-9a-f]*\).*/\1/p' "$TEST_ROOT/p7.handoff")
if [ -n "$pushed_sha" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse --short=7 refs/heads/hyperpowers/state)" = "$pushed_sha" ] && [ "$(git -C "$PAIR_A" rev-parse --short=7 hyperpowers/state)" != "$pushed_sha" ] && grep -q '^status=snapshot' "$TEST_ROOT/p7.snap"; then pass "a snapshot queued during a hand-off waits; the push carries the scanned commit only"; else fail "a snapshot queued during a hand-off waits ($(cat "$TEST_ROOT/p7.handoff") / $(cat "$TEST_ROOT/p7.snap"))"; fi
git -C "$PAIR_A" config --unset hyperpowers.prePushScan
# The remote rewound between the scan and the push: the lease refuses it.
git -C "$PAIR_A" config hyperpowers.prePushScan 'cat > /dev/null'
remote_before=$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)
printf 'lease\n' > "$wsa/task-10-report.md"
: > "$co_a7/.handoff-pause"
( cd "$PAIR_A" && HYPERPOWERS_TEST_PAUSE_AT=handoff-after-scan bash "$SDD_STATE" handoff docs/plan.md --push > "$TEST_ROOT/p7.lease" 2>/dev/null ) &
n=0; while [ ! -e "$co_a7/.handoff-paused" ] && [ "$n" -lt 300 ]; do sleep 0.1; n=$((n + 1)); done
git -C "$PAIR_REMOTE" update-ref refs/heads/hyperpowers/state "$remote_before^"
rm -f "$co_a7/.handoff-pause"; wait
if [ "$(cut -d' ' -f1 "$TEST_ROOT/p7.lease")" = "status=push-failed" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)" = "$(git -C "$PAIR_REMOTE" rev-parse "$remote_before^")" ]; then pass "a remote that moved between the scan and the push is refused by the lease, nothing overwritten"; else fail "a remote that moved between the scan and the push is refused by the lease, nothing overwritten ($(cat "$TEST_ROOT/p7.lease"))"; fi
git -C "$PAIR_REMOTE" update-ref refs/heads/hyperpowers/state "$remote_before"
out=$(run_state "$PAIR_A" handoff docs/plan.md --push); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pushed" ]; then pass "with the remote back where the scan saw it the push lands"; else fail "with the remote back where the scan saw it the push lands (rc=$rc: $out)"; fi
git -C "$PAIR_A" config --unset hyperpowers.prePushScan
git -C "$PAIR_A" checkout -q --detach
out=$(run_state "$PAIR_A" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=detached-head repo=code" ]; then pass "a detached code checkout cannot hand off"; else fail "a detached code checkout cannot hand off (rc=$rc: $out)"; fi
git -C "$PAIR_A" checkout -q main

# Arrival on the second host after a real hand-off.
out=$(run_state "$PAIR_B" sync docs/plan.md)
if [ "${out%% *}" = "status=created" ]; then pass "the second host receives the handed-off dossier"; else fail "the second host receives the handed-off dossier ($out)"; fi
out=$(run_state "$PAIR_B" verify docs/plan.md); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% *}" = "status=code-missing" ]; then pass "arrival before the code pull is code-missing"; else fail "arrival before the code pull is code-missing (rc=$rc: $out)"; fi
git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
if [ "$(run_state "$PAIR_B" verify docs/plan.md)" = "status=ok tasks=1" ]; then pass "arrival after the code pull verifies"; else fail "arrival after the code pull verifies"; fi
# The remote moved since the last sync: refused before the scan, nothing
# overwritten; a sync makes it a plain push again.
wsb10="$STATE_ROOT/$(state_key "$PAIR_B")/plans/$(basename "$wsa")"
printf 'B line\n' >> "$wsb10/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
remote_b=$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)
out=$(run_state "$PAIR_A" handoff docs/plan.md --push 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% *}" = "status=push-failed" ] && [ "$(git -C "$PAIR_REMOTE" rev-parse refs/heads/hyperpowers/state)" = "$remote_b" ]; then pass "a remote that moved since the last sync is push-failed before the scan, nothing overwritten"; else fail "a remote that moved since the last sync is push-failed before the scan, nothing overwritten (rc=$rc: $out)"; fi
run_state "$PAIR_A" sync docs/plan.md >/dev/null
out=$(run_state "$PAIR_A" handoff docs/plan.md --push); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=pushed" ] && git -C "$PAIR_REMOTE" merge-base --is-ancestor "$remote_b" refs/heads/hyperpowers/state; then pass "after a sync the hand-off pushes on top of the other host's line"; else fail "after a sync the hand-off pushes on top of the other host's line (rc=$rc: $out)"; fi
# A cleanliness check that cannot run is an error, never a clean tree.
badidx="$TEST_ROOT/hostA/p10-badidx"; git clone -q "$PAIR_REMOTE" "$badidx" 2>/dev/null
git -C "$badidx" config user.name t; git -C "$badidx" config user.email t@example.com
run_state "$badidx" sync docs/plan.md >/dev/null
printf 'garbage\n' > "$badidx/.git/index"
out=$(run_state "$badidx" handoff docs/plan.md --plan-untracked-ok 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "a code tree whose status cannot be read is an error, not clean"; else fail "a code tree whose status cannot be read is an error, not clean (rc=$rc: $out)"; fi
# A shallow source would record a boundary commit as the identity.
shallow10="$TEST_ROOT/hostA/p10-shallow"; git clone -q --depth 1 "file://$PAIR_REMOTE" "$shallow10" 2>/dev/null
git -C "$shallow10" config user.name t; git -C "$shallow10" config user.email t@example.com
run_state "$shallow10" sync docs/plan.md >/dev/null
out=$(run_state "$shallow10" handoff docs/plan.md); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=shallow-source repo=code" ]; then pass "a shallow code clone cannot hand off"; else fail "a shallow code clone cannot hand off (rc=$rc: $out)"; fi
if [ "$(run_state "$rp" handoff docs/plan.md 2>/dev/null)" = "status=plain" ]; then pass "handoff under the plain backend reports plain"; else fail "handoff under the plain backend reports plain"; fi
rc=0; run_state "$rp" handoff docs/plan.md >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 7 ]; then pass "handoff under the plain backend exits 7"; else fail "handoff under the plain backend exits 7 (rc=$rc)"; fi

# A ledger or workspace that is a symbolic link is refused, and the link's
# target is never written.
outside="$TEST_ROOT/outside"; mkdir -p "$outside/ws"; printf 'untouched\n' > "$outside/sentinel"; printf 'untouched\n' > "$outside/ws/progress.md"
mv "$wsa/progress.md" "$wsa/progress.md.real"; ln -s "$outside/sentinel" "$wsa/progress.md"
out=$(run_state "$PAIR_A" handoff docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(cat "$outside/sentinel")" = "untouched" ]; then pass "a ledger that is a symbolic link is refused and its target is untouched"; else fail "a ledger that is a symbolic link is refused and its target is untouched (rc=$rc: $out)"; fi
rm -f "$wsa/progress.md"; mv "$wsa/progress.md.real" "$wsa/progress.md"
mv "$wsa" "$wsa.real"; ln -s "$outside/ws" "$wsa"
out=$(run_state "$PAIR_A" handoff docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(cat "$outside/ws/progress.md")" = "untouched" ] && [ ! -e "$outside/ws/task-1-report.md" ]; then pass "a workspace that is a symbolic link is refused and its target is untouched"; else fail "a workspace that is a symbolic link is refused and its target is untouched (rc=$rc: $out)"; fi
rm -f "$wsa"; mv "$wsa.real" "$wsa"

# Cross-repository: plan in P, code in C; a clean destination pulls both.
make_pair p10plan; P_A=$PAIR_A; P_B=$PAIR_B
make_pair p10code; C_A=$PAIR_A; C_B=$PAIR_B
mkdir -p "$P_A/docs"; : > "$P_A/docs/plan.md"; git -C "$P_A" add docs; git -C "$P_A" commit -qm plan; git -C "$P_A" push -q origin main 2>/dev/null
( cd "$C_A" && bash "$SDD_STATE" sync "$P_A/docs/plan.md" >/dev/null )
wsp=$(cd "$C_A" && bash "$SDD_DIR" "$P_A/docs/plan.md")
printf 'code\n' > "$C_A/code.txt"; git -C "$C_A" add code.txt; git -C "$C_A" commit -qm "task 1"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits %s..%s, review clean)\n' "$(git -C "$C_A" rev-parse --short=7 HEAD~1)" "$(git -C "$C_A" rev-parse --short=7 HEAD)" > "$wsp/progress.md"
out=$(cd "$C_A" && bash "$SDD_STATE" handoff "$P_A/docs/plan.md" --push); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=pushed sha=$(git -C "$P_A" rev-parse --short=7 hyperpowers/state) code=main@$(git -C "$C_A" rev-parse --short=7 HEAD) plan=main@$(git -C "$P_A" rev-parse --short=7 HEAD)" ] && grep -q "^handoff: plan root=[0-9a-f]\{40\} main@$(git -C "$P_A" rev-parse HEAD)\$" "$wsp/progress.md" && grep -q "^handoff: code root=[0-9a-f]\{40\} main@$(git -C "$C_A" rev-parse HEAD) at " "$wsp/progress.md"; then pass "a cross-repository handoff records and names the plan branch"; else fail "a cross-repository handoff records and names the plan branch (rc=$rc: $out)"; fi
git -C "$C_A" push -q origin main 2>/dev/null
git -C "$P_B" pull -q origin main 2>/dev/null; git -C "$C_B" pull -q origin main 2>/dev/null
( cd "$C_B" && bash "$SDD_STATE" sync "$P_B/docs/plan.md" >/dev/null )
out=$(cd "$C_B" && bash "$SDD_STATE" verify "$P_B/docs/plan.md"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=ok tasks=1" ]; then pass "clean clones of both repositories verify after pulling the named branches"; else fail "clean clones of both repositories verify after pulling the named branches (rc=$rc: $out)"; fi

echo ""
echo "=== leftover entries under plans/ ==="
# A leftover entry directly under plans/ must not wedge every later sync.
make_pair p11
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; wsb="$co_b/plans/$(basename "$wsa")"
advance() { printf '%s\n' "$1" >> "$wsa/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; }
# A tomb a killed finish or prune left for a plan no later call revisits.
tomb_p11="$co_b/plans/.removing-gone-1234abcd-999"
mkdir -p "$tomb_p11"; printf 'orphaned copy\n' > "$tomb_p11/progress.md"
quar_p11="$co_b/plans/.pruned-gone-1234abcd-999"; mkdir -p "$quar_p11"; printf 'quarantined copy\n' > "$quar_p11/progress.md"
# Names with a space: git status quotes such paths, and the scan must still
# see the leftovers for what they are.
tomb_p11s="$co_b/plans/.removing-old plan-1234abcd-999"; mkdir -p "$tomb_p11s"; printf 'orphaned copy\n' > "$tomb_p11s/progress.md"
quar_p11s="$co_b/plans/.pruned-old plan-1234abcd-999"; mkdir -p "$quar_p11s"; printf 'quarantined copy\n' > "$quar_p11s/progress.md"
advance 'line one'
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^line one$' "$wsb/progress.md" && [ -d "$tomb_p11" ] && [ -d "$quar_p11" ] && [ -d "$tomb_p11s" ] && [ -d "$quar_p11s" ]; then pass "a tomb or a quarantine left under plans/ by a removal, with or without a space in its name, does not stop the apply"; else fail "a tomb or a quarantine left under plans/ by a removal, with or without a space in its name, does not stop the apply (rc=$rc: $out)"; fi
rm -rf "$tomb_p11" "$quar_p11" "$tomb_p11s" "$quar_p11s"
# Any other leftover entry still stops the apply, and names itself.
printf 'stray\n' > "$co_b/plans/stray.txt"
advance 'line two'
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11.out" 2> "$TEST_ROOT/p11.err"; rc=$?
out=$(cat "$TEST_ROOT/p11.out")
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && grep -q 'plans/stray.txt' "$TEST_ROOT/p11.err"; then pass "another leftover entry under plans/ is busy with the path named on stderr"; else fail "another leftover entry under plans/ is busy with the path named on stderr (rc=$rc: $out: $(cat "$TEST_ROOT/p11.err"))"; fi
rm -f "$co_b/plans/stray.txt"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^line two$' "$wsb/progress.md"; then pass "the apply resumes once the named entry is gone"; else fail "the apply resumes once the named entry is gone (rc=$rc: $out)"; fi
# A crash inside the recovery between its ref move and its tomb loop: the
# tombs go before the ref, so the crash leaves nothing under plans/.
: > "$PAIR_A/docs/fin.md"; git -C "$PAIR_A" add docs/fin.md; git -C "$PAIR_A" commit -qm fin; git -C "$PAIR_A" push -q origin main 2>/dev/null; git -C "$PAIR_B" pull -q origin main 2>/dev/null
wsf=$(run_sdd_dir "$PAIR_A" docs/fin.md); printf '# SDD ledger — plan: docs/fin.md\n' > "$wsf/progress.md"
run_state "$PAIR_A" snapshot docs/fin.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
run_state "$PAIR_A" finish docs/fin.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-after-marker bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 )
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=recover-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_b/.sync-applying" ] && ! ls -d "$co_b/plans/.removing-$(basename "$wsf")-"* >/dev/null 2>&1; then pass "the recovery deletes the verified copies before it moves the ref"; else fail "the recovery deletes the verified copies before it moves the ref (rc=$rc)"; fi
advance 'line three'
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ ! -f "$co_b/.sync-applying" ] && [ ! -d "$co_b/plans/$(basename "$wsf")" ] && grep -q '^line three$' "$wsb/progress.md"; then pass "the next sync after that crash finishes the apply and keeps going"; else fail "the next sync after that crash finishes the apply and keeps going (rc=$rc: $out)"; fi
# A workspace the branch tracks under a leftover's name (a plan file from
# before this release whose name began with a dot): its dirty report holds
# the apply like any other workspace's, and a remote change to the same
# path never overwrites it.
co_a11="$STATE_ROOT/$(state_key "$PAIR_A")"; legacy11=".pruned-legacy-12345678"
mkdir -p "$co_a11/plans/$legacy11"; printf '# SDD ledger — plan: docs/legacy.md\n' > "$co_a11/plans/$legacy11/progress.md"; printf 'report v1\n' > "$co_a11/plans/$legacy11/task-1-report.md"
git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm legacy && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'local edit\n' > "$co_b/plans/$legacy11/task-1-report.md"
printf 'report v2\n' > "$co_a11/plans/$legacy11/task-1-report.md"; git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm legacy2 && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11c.out" 2> "$TEST_ROOT/p11c.err"; rc=$?
out=$(cat "$TEST_ROOT/p11c.out")
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && grep -q "plans/$legacy11/task-1-report.md" "$TEST_ROOT/p11c.err" && [ "$(cat "$co_b/plans/$legacy11/task-1-report.md")" = "local edit" ]; then pass "a dirty report in a tracked workspace named like a leftover holds the apply and is not overwritten"; else fail "a dirty report in a tracked workspace named like a leftover holds the apply and is not overwritten (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11c.err"))"; fi
printf 'report v1\n' > "$co_b/plans/$legacy11/task-1-report.md"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$co_b/plans/$legacy11/task-1-report.md")" = "report v2" ]; then pass "with the local edit put back the apply proceeds and the remote change lands"; else fail "with the local edit put back the apply proceeds and the remote change lands (rc=$rc: $out)"; fi
# The same for a tracked file directly under plans/ whose name reads like a
# leftover: a file is not a workspace directory, so the tracked lookup must
# not ask for a tree, or the exemption would swallow the file's dirty row
# and the apply would write over the local bytes.
file11="plans/.removing-trackedfile-12345678"
printf 'tracked v1\n' > "$co_a11/$file11"
git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm trackedfile && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
printf 'local edit\n' > "$co_b/$file11"
printf 'tracked v2\n' > "$co_a11/$file11"; git -C "$co_a11" add -A plans/ && git -C "$co_a11" commit -qm trackedfile2 && git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11d.out" 2> "$TEST_ROOT/p11d.err"; rc=$?
out=$(cat "$TEST_ROOT/p11d.out")
if [ "$rc" -eq 3 ] && [ "${out%% *}" = "status=busy" ] && grep -q "$file11" "$TEST_ROOT/p11d.err" && [ "$(cat "$co_b/$file11")" = "local edit" ]; then pass "a dirty tracked file under plans/ named like a leftover holds the apply and is not overwritten"; else fail "a dirty tracked file under plans/ named like a leftover holds the apply and is not overwritten (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11d.err"))"; fi
printf 'tracked v1\n' > "$co_b/$file11"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$co_b/$file11")" = "tracked v2" ]; then pass "with that edit reverted the apply fast-forwards and the remote change lands"; else fail "with that edit reverted the apply fast-forwards and the remote change lands (rc=$rc: $out)"; fi
# A leftover as the only entry under plans/: with no tracked entry there,
# git collapses the directory to one `?? plans/` row, which no exemption
# names and whose advice (move or delete the dossier root) is wrong; the
# scan lists untracked files one by one, so the row is the leftover's own.
make_pair p11b
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b11="$STATE_ROOT/$(state_key "$PAIR_B")"
sole11="$co_b11/plans/.removing-gone-1234abcd-999"; mkdir -p "$sole11"; printf 'orphaned copy\n' > "$sole11/progress.md"
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11b.out" 2> "$TEST_ROOT/p11b.err"; rc=$?
out=$(cat "$TEST_ROOT/p11b.out")
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ -f "$co_b11/plans/$(basename "$wsa")/progress.md" ] && [ -d "$sole11" ] && ! grep -q 'plans/ is not part of a plan workspace' "$TEST_ROOT/p11b.err"; then pass "a leftover that is the only entry under plans/ does not stop the apply"; else fail "a leftover that is the only entry under plans/ does not stop the apply (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11b.err"))"; fi
rm -rf "$sole11"
# An incoming commit whose first version adds a tracked entry of a dotted
# name a local removal or prune copy already holds. The exemption reads S
# alone, so without the target's side of it the apply would write the
# incoming files into that copy, which may be the only one of its dossier.
# The helper never makes such a name (hp_plan_ws_name strips leading dots),
# so the commit is built with plumbing.
make_pair p11c
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa11c=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa11c/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b11c="$STATE_ROOT/$(state_key "$PAIR_B")"
dotted11c=".pruned-collide-1234abcd-999"
copy11c="$co_b11c/plans/$dotted11c"
mkdir -p "$copy11c"; printf '# SDD ledger — plan: docs/gone.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$copy11c/progress.md"; printf 'the only report\n' > "$copy11c/task-1-report.md"
cp -a "$copy11c" "$TEST_ROOT/p11c-before"
before11c=$(git -C "$PAIR_B" rev-parse hyperpowers/state)
# The first version of that path on the branch, added by hand on A.
idx11c="$TEST_ROOT/p11c.index"; tip11c=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
lb11c=$(printf 'incoming ledger\n' | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx11c"; GIT_INDEX_FILE=$idx11c git -C "$PAIR_A" read-tree "$tip11c"
GIT_INDEX_FILE=$idx11c git -C "$PAIR_A" update-index --add --cacheinfo "100644,$lb11c,plans/$dotted11c/progress.md"
add11c=$(printf 'a dotted workspace added by hand\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx11c git -C "$PAIR_A" write-tree)" -p "$tip11c")
git -C "$PAIR_A" push -q origin "$add11c:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p11c.out" 2> "$TEST_ROOT/p11c.err"; rc=$?
out=$(cat "$TEST_ROOT/p11c.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q "plans/$dotted11c" "$TEST_ROOT/p11c.err" && grep -qF "mv '$copy11c' '$co_b11c/.aside-$dotted11c-" "$TEST_ROOT/p11c.err" && diff -r "$TEST_ROOT/p11c-before" "$copy11c" >/dev/null 2>&1 && [ "$(git -C "$PAIR_B" rev-parse hyperpowers/state)" = "$before11c" ] && [ ! -f "$co_b11c/.sync-applying" ]; then pass "an incoming first-add of a dotted name a local removal copy holds is refused, the copy intact and the branch unmoved"; else fail "an incoming first-add of a dotted name a local removal copy holds is refused (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/p11c.err"))"; fi
# Why the line names a path outside plans/: a copy left under plans/ whose
# name still ends in a pid parses as a quarantine, and a later prune
# --apply would delete the copy the refusal exists to protect.
mv "$copy11c" "$copy11c.aside-4242"
find "$copy11c.aside-4242" -depth -exec touch -t 202401010000 {} +
out=$(run_state "$PAIR_B" prune --repo "$PAIR_B" 2>/dev/null)
if printf '%s' "$out" | grep -q "$dotted11c\.aside-4242"; then pass "a copy moved aside under plans/ is listed by prune, which is why the refusal does not name one"; else fail "a copy moved aside under plans/ is listed by prune ($out)"; fi
# The repair the line does name: a root-level path nothing sweeps, scans,
# lists or commits.
mv "$copy11c.aside-4242" "$co_b11c/.aside-$dotted11c-4242"
out=$(run_state "$PAIR_B" prune --repo "$PAIR_B" 2>/dev/null)
if ! printf '%s' "$out" | grep -q aside; then pass "the root-level path the refusal names is listed by nothing"; else fail "the root-level path the refusal names is listed by nothing ($out)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ "$(cat "$co_b11c/plans/$dotted11c/progress.md")" = "incoming ledger" ] && [ -f "$co_b11c/.aside-$dotted11c-4242/task-1-report.md" ] && [ -z "$(git -C "$co_b11c" status --porcelain -- plans/)" ]; then pass "with the local copy moved out of plans/ the incoming workspace of that name is applied"; else fail "with the local copy moved out of plans/ the incoming workspace of that name is applied (rc=$rc: $out)"; fi
rm -rf "$co_b11c/.aside-$dotted11c-4242"

echo ""
echo "=== containment on the apply path ==="
# A state branch a remote carries can hold plans/<ws> as a symbolic link,
# and the apply writes with shell redirection: it must refuse instead.
make_pair p12
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
outside12="$TEST_ROOT/outside-p12"; mkdir -p "$outside12"; printf 'untouched\n' > "$outside12/sentinel"
idx12="$TEST_ROOT/p12.index"
tip12=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
link12=$(printf '%s' "$outside12" | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx12"; GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" read-tree "$tip12"
GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" update-index --add --cacheinfo "120000,$link12,plans/evil"
tree12=$(GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" write-tree)
evil1=$(printf 'a workspace that is a link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$tree12" -p "$tip12")
git -C "$PAIR_A" push -q origin "$evil1:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p12.out" 2> "$TEST_ROOT/p12.err"; rc=$?
out=$(cat "$TEST_ROOT/p12.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$co_b/plans/evil" ] && [ ! -L "$co_b/plans/evil" ] && [ ! -e "$outside12/progress.md" ] && grep -q 'plans/evil' "$TEST_ROOT/p12.err"; then pass "a workspace the branch carries as a symbolic link is refused before the checkout can materialize it"; else fail "a workspace the branch carries as a symbolic link is refused before the checkout can materialize it (rc=$rc: $out: $(cat "$TEST_ROOT/p12.err"))"; fi
if grep -q 'Remove it on the host that committed it and commit the removal on the state branch (snapshot does that for a path under plans/; a root-level one needs a commit on the branch itself), push, then sync again' "$TEST_ROOT/p12.err"; then pass "the refusal says what to do about the link"; else fail "the refusal says what to do about the link ($(cat "$TEST_ROOT/p12.err"))"; fi
if [ ! -f "$co_b/.sync-applying" ] && [ "$(git -C "$co_b" rev-parse hyperpowers/state)" = "$tip12" ]; then pass "the refusal comes before anything is applied: no marker, the ref unmoved"; else fail "the refusal comes before anything is applied: no marker, the ref unmoved"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$outside12/progress.md" ] && [ "$(cat "$outside12/sentinel")" = "untouched" ]; then pass "a second sync refuses the same way and still writes nothing outside the checkout"; else fail "a second sync refuses the same way and still writes nothing outside the checkout (rc=$rc: $out)"; fi
# A later commit that replaces the link with a real directory is applied:
# the refusal is about the tree being applied, not about the branch's past.
ledger12=$(printf '# SDD ledger — plan: docs/evil.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx12"; GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" read-tree "$evil1"
GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" update-index --force-remove plans/evil
GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$ledger12,plans/evil/progress.md"
tree12=$(GIT_INDEX_FILE=$idx12 git -C "$PAIR_A" write-tree)
evil2=$(printf 'a ledger under the link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$tree12" -p "$evil1")
git -C "$PAIR_A" push -q origin "$evil2:refs/heads/hyperpowers/state" 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && [ -f "$co_b/plans/evil/progress.md" ] && [ ! -L "$co_b/plans/evil" ] && [ "$(cat "$outside12/sentinel")" = "untouched" ]; then pass "once the branch replaces the link with a real directory the apply goes through"; else fail "once the branch replaces the link with a real directory the apply goes through (rc=$rc: $out)"; fi

echo ""
echo "=== import recovery when the source outgrew the published copy ==="
# A cutover interrupted after publication whose legacy source then gained a
# report and a ledger line: the extra entries are installed, not skipped.
i18="$TEST_ROOT/i18"; make_repo "$i18"; mkdir -p "$i18/docs"; : > "$i18/docs/plan.md"; git -C "$i18" add docs; git -C "$i18" commit -qm plan
wsi18=$(ws_path "$i18" "$i18/docs/plan.md"); mkdir -p "$wsi18"
legacy_i18="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i18")/plans/$(basename "$wsi18")"
mkdir -p "$legacy_i18.importing-557"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i18" > "$legacy_i18.importing-557/progress.md"
printf 'report one\n' > "$legacy_i18.importing-557/task-1-report.md"
printf 'report two\n' > "$legacy_i18.importing-557/task-2-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsi18/progress.md"
printf 'report one\n' > "$wsi18/task-1-report.md"
out=$(run_state "$i18" import docs/plan.md); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy_i18" ] && [ -L "$legacy_i18" ] && ! ls -d "$legacy_i18.importing-"* >/dev/null 2>&1; then pass "a published destination the source outgrew is finished, not reported as ledger-exists"; else fail "a published destination the source outgrew is finished, not reported as ledger-exists (rc=$rc: $out)"; fi
if [ -f "$wsi18/task-2-report.md" ] && [ "$(sed -n 3p "$wsi18/progress.md")" = "Task 2: complete (commits 3333333..4444444, review clean)" ] && [ "$(head -n 1 "$wsi18/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "the entries the source gained after publication are installed, the ledger last"; else fail "the entries the source gained after publication are installed, the ledger last ($(cat "$wsi18/progress.md"))"; fi


echo ""
echo "=== sync recovery in a sha256 repository ==="
# The sync marker holds two object ids. A repository with
# extensions.objectFormat = sha256 writes 64-character ids, so a marker
# validated by length would be rejected there and recovery would never run.
# The pair is built by hand: make_pair creates sha1 repositories.
p13_remote="$TEST_ROOT/p13.git"
git init -q --bare -b main --object-format=sha256 "$p13_remote"
p13_a="$TEST_ROOT/hostA/p13"; mkdir -p "$(dirname "$p13_a")"
git clone -q "$p13_remote" "$p13_a" 2>/dev/null
git -C "$p13_a" config user.name "Host A"; git -C "$p13_a" config user.email "a@example.com"
git -C "$p13_a" commit -q --allow-empty -m "initial"
git -C "$p13_a" push -q origin main 2>/dev/null
p13_b="$TEST_ROOT/hostB/p13"; mkdir -p "$(dirname "$p13_b")"
git clone -q "$p13_remote" "$p13_b" 2>/dev/null
git -C "$p13_b" config user.name "Host B"; git -C "$p13_b" config user.email "b@example.com"
mkdir -p "$p13_a/docs"; : > "$p13_a/docs/plan.md"; git -C "$p13_a" add docs; git -C "$p13_a" commit -qm plan; git -C "$p13_a" push -q origin main 2>/dev/null
git -C "$p13_b" pull -q origin main 2>/dev/null
if [ "$(git -C "$p13_a" rev-parse --show-object-format)" = sha256 ] && [ "$(git -C "$p13_b" rev-parse --show-object-format)" = sha256 ]; then pass "the fixture pair uses sha256 object ids"; else fail "the fixture pair uses sha256 object ids"; fi
co13_b="$STATE_ROOT/$(state_key "$p13_b")"
run_state "$p13_a" sync docs/plan.md >/dev/null
ws13=$(run_sdd_dir "$p13_a" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\n' > "$ws13/progress.md"
run_state "$p13_a" snapshot docs/plan.md >/dev/null; git -C "$p13_a" push -q origin hyperpowers/state 2>/dev/null
run_state "$p13_b" sync docs/plan.md >/dev/null
ws13b="$co13_b/plans/$(basename "$ws13")"
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$ws13/progress.md"
run_state "$p13_a" snapshot docs/plan.md >/dev/null; git -C "$p13_a" push -q origin hyperpowers/state 2>/dev/null
( cd "$p13_b" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
m13_s=""; m13_t=""; read -r m13_s m13_t < "$co13_b/.sync-applying" 2>/dev/null
if [ "$rc" -eq 99 ] && [ "${#m13_s}" -eq 64 ] && [ "${#m13_t}" -eq 64 ]; then pass "the crash seam leaves a marker holding two 64-character ids"; else fail "the crash seam leaves a marker holding two 64-character ids (rc=$rc, '$m13_s $m13_t')"; fi
run_state "$p13_b" sync docs/plan.md > "$TEST_ROOT/p13.out" 2> "$TEST_ROOT/p13.err"; rc=$?
out=$(cat "$TEST_ROOT/p13.out")
case "${out%% *}" in status=up-to-date|status=fast-forwarded) ff13=1 ;; *) ff13=0 ;; esac
if [ "$rc" -eq 0 ] && [ "$ff13" -eq 1 ] && [ ! -f "$co13_b/.sync-applying" ] && grep -q '^Task 1: complete' "$ws13b/progress.md"; then pass "an interrupted apply in a sha256 repository is recovered and the marker is gone"; else fail "an interrupted apply in a sha256 repository is recovered and the marker is gone (rc=$rc: $out: $(cat "$TEST_ROOT/p13.err"))"; fi

echo ""
echo "=== a killed removal must not wedge another plan's sync ==="
# finish and prune rename a workspace aside before they verify it. Killed
# there, the copy plus the deleted tracked rows it leaves held every later
# sync on the repository: only a later call for that same plan revisits them.
make_pair p14
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; : > "$PAIR_A/docs/x.md"; : > "$PAIR_A/docs/z.md"
git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plans; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b14="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsy=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsy/progress.md"
wsx=$(run_sdd_dir "$PAIR_A" docs/x.md); printf '# SDD ledger — plan: docs/x.md\n' > "$wsx/progress.md"
wsz=$(run_sdd_dir "$PAIR_A" docs/z.md); printf '# SDD ledger — plan: docs/z.md\n' > "$wsz/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
run_state "$PAIR_A" snapshot docs/x.md >/dev/null
GIT_COMMITTER_DATE="2026-01-01T00:00:00Z" GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" run_state "$PAIR_A" snapshot docs/z.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
wsy_b="$co_b14/plans/$(basename "$wsy")"; wsx_b="$co_b14/plans/$(basename "$wsx")"; wsz_b="$co_b14/plans/$(basename "$wsz")"
advance14() { printf '%s\n' "$1" >> "$wsy/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null; }
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=remove-after-rename bash "$SDD_STATE" finish docs/x.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ ! -d "$wsx_b" ] && ls -d "$co_b14/plans/.removing-$(basename "$wsx")-"* >/dev/null 2>&1; then pass "the seam leaves finish's copy renamed aside"; else fail "the seam leaves finish's copy renamed aside (rc=$rc)"; fi
advance14 'line after the killed finish'
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p14a.out" 2> "$TEST_ROOT/p14a.err"; rc=$?
out=$(cat "$TEST_ROOT/p14a.out")
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^line after the killed finish$' "$wsy_b/progress.md"; then pass "a sync for another plan is not held by the killed finish"; else fail "a sync for another plan is not held by the killed finish (rc=$rc: $out: $(cat "$TEST_ROOT/p14a.err"))"; fi
if [ -f "$wsx_b/progress.md" ] && ! ls -d "$co_b14/plans/.removing-"* >/dev/null 2>&1 && [ -z "$(git -C "$co_b14" status --porcelain -- plans/)" ]; then pass "the killed finish's dossier is back and its deleted rows are gone"; else fail "the killed finish's dossier is back and its deleted rows are gone ($(git -C "$co_b14" status --porcelain -- plans/ | tr '\n' ' '))"; fi
touch -t 202601010000 "$wsz_b/progress.md" "$wsz_b"
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=remove-after-rename bash "$SDD_STATE" prune --repo "$PAIR_B" --apply >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ ! -d "$wsz_b" ] && ls -d "$co_b14/plans/.removing-$(basename "$wsz")-"* >/dev/null 2>&1; then pass "the seam leaves prune's copy renamed aside"; else fail "the seam leaves prune's copy renamed aside (rc=$rc)"; fi
advance14 'line after the killed prune'
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p14b.out" 2> "$TEST_ROOT/p14b.err"; rc=$?
out=$(cat "$TEST_ROOT/p14b.out")
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^line after the killed prune$' "$wsy_b/progress.md"; then pass "a sync for another plan is not held by the killed prune"; else fail "a sync for another plan is not held by the killed prune (rc=$rc: $out: $(cat "$TEST_ROOT/p14b.err"))"; fi
if [ -f "$wsz_b/progress.md" ] && ! ls -d "$co_b14/plans/.removing-"* >/dev/null 2>&1 && [ -z "$(git -C "$co_b14" status --porcelain -- plans/)" ]; then pass "the killed prune's dossier is back and its deleted rows are gone"; else fail "the killed prune's dossier is back and its deleted rows are gone ($(git -C "$co_b14" status --porcelain -- plans/ | tr '\n' ' '))"; fi
# A copy stranded beside a workspace path that is occupied again is a
# human's to merge: it stays, and the message names it and the workspace,
# never telling the human to move or delete a file that is gone.
mv "$wsx_b" "$co_b14/plans/.removing-$(basename "$wsx")-4242"; mkdir -p "$wsx_b"
advance14 'line beside the stranded copy'
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p14c.out" 2> "$TEST_ROOT/p14c.err"; rc=$?
out=$(cat "$TEST_ROOT/p14c.out")
if [ "$rc" -eq 0 ] && [ -d "$co_b14/plans/.removing-$(basename "$wsx")-4242" ] && grep -q "removing-$(basename "$wsx")-4242" "$TEST_ROOT/p14c.err" && grep -q "$wsx_b" "$TEST_ROOT/p14c.err" && ! grep -q "progress.md is not part of a plan workspace" "$TEST_ROOT/p14c.err"; then pass "a copy stranded beside an occupied workspace stays, named with the workspace"; else fail "a copy stranded beside an occupied workspace stays, named with the workspace (rc=$rc: $out: $(cat "$TEST_ROOT/p14c.err"))"; fi
# The human moves the copy back: the next sync takes the dossier with it.
rmdir "$wsx_b"; mv "$co_b14/plans/.removing-$(basename "$wsx")-4242" "$wsx_b"
advance14 'line after the copy came back'
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$wsx_b/progress.md" ] && [ -z "$(git -C "$co_b14" status --porcelain -- plans/)" ] && grep -q '^line after the copy came back$' "$wsy_b/progress.md"; then pass "once the human puts the copy back the apply carries on and the tree is clean"; else fail "once the human puts the copy back the apply carries on and the tree is clean (rc=$rc: $out: $(git -C "$co_b14" status --porcelain -- plans/ | tr '\n' ' '))"; fi

echo ""
echo "=== containment of the paths the apply writes at the checkout root ==="
# A leaf inside a workspace can be a link too, and the marker and the
# rewrite journal are written at the checkout root, where nothing checked
# them.
make_pair p15
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b15="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa15=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa15/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
wsb15="$co_b15/plans/$(basename "$wsa15")"
outside15="$TEST_ROOT/outside-p15"; mkdir -p "$outside15"; printf 'untouched\n' > "$outside15/sentinel"
idx15="$TEST_ROOT/p15.index"
tip15=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
leaf15=$(printf '%s' "$outside15/sentinel" | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx15"; GIT_INDEX_FILE=$idx15 git -C "$PAIR_A" read-tree "$tip15"
GIT_INDEX_FILE=$idx15 git -C "$PAIR_A" update-index --add --cacheinfo "120000,$leaf15,plans/$(basename "$wsa15")/task-1-report.md"
tree15=$(GIT_INDEX_FILE=$idx15 git -C "$PAIR_A" write-tree)
evil15=$(printf 'a report that is a link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$tree15" -p "$tip15")
git -C "$PAIR_A" push -q origin "$evil15:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p15.out" 2> "$TEST_ROOT/p15.err"; rc=$?
out=$(cat "$TEST_ROOT/p15.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$wsb15/task-1-report.md" ] && [ ! -L "$wsb15/task-1-report.md" ] && grep -q 'task-1-report.md' "$TEST_ROOT/p15.err"; then pass "a leaf the branch carries as a symbolic link inside a workspace is refused, naming it"; else fail "a leaf the branch carries as a symbolic link inside a workspace is refused, naming it (rc=$rc: $out: $(cat "$TEST_ROOT/p15.err"))"; fi
if [ ! -f "$co_b15/.sync-applying" ] && [ "$(git -C "$co_b15" rev-parse hyperpowers/state)" = "$tip15" ] && [ "$(cat "$outside15/sentinel")" = "untouched" ]; then pass "the leaf refusal moves nothing: no marker, the ref unmoved, the target untouched"; else fail "the leaf refusal moves nothing: no marker, the ref unmoved, the target untouched"; fi
# The sync marker: a link at its path would put the marker outside the cache.
make_pair p16
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_a16="$STATE_ROOT/$(state_key "$PAIR_A")"; co_b16="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa16=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa16/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
wsb16="$co_b16/plans/$(basename "$wsa16")"
outside16="$TEST_ROOT/outside-p16"; mkdir -p "$outside16"
ln -s "$outside16/marker" "$co_b16/.sync-applying"
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsa16/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
tip16=$(git -C "$co_b16" rev-parse hyperpowers/state)
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p16.out" 2> "$TEST_ROOT/p16.err"; rc=$?
out=$(cat "$TEST_ROOT/p16.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$outside16/marker" ] && grep -q '.sync-applying is a symbolic link' "$TEST_ROOT/p16.err" && [ "$(git -C "$co_b16" rev-parse hyperpowers/state)" = "$tip16" ]; then pass "a symbolic link at the sync marker's path is refused and nothing is written through it"; else fail "a symbolic link at the sync marker's path is refused and nothing is written through it (rc=$rc: $out: $(cat "$TEST_ROOT/p16.err"))"; fi
rm -f "$co_b16/.sync-applying"
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=fast-forwarded" ] && grep -q '^Task 1: complete' "$wsb16/progress.md"; then pass "with the link gone the same sync applies"; else fail "with the link gone the same sync applies (rc=$rc: $out)"; fi
# The rewrite journal: the same at .rewrite/, which only a rewritten ledger
# creates. Both hosts append, B merges, and A fast-forwards onto the merge.
git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
printf 'walk A\n' >> "$wsa16/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'walk B\n' >> "$wsb16/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
outside16b="$TEST_ROOT/outside-p16-rewrite"; mkdir -p "$outside16b"
ln -s "$outside16b" "$co_a16/.rewrite"
run_state "$PAIR_A" sync docs/plan.md > "$TEST_ROOT/p16b.out" 2> "$TEST_ROOT/p16b.err"; rc=$?
out=$(cat "$TEST_ROOT/p16b.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q '.rewrite is a symbolic link' "$TEST_ROOT/p16b.err" && [ -z "$(ls -A "$outside16b")" ]; then pass "a symbolic link at the rewrite journal's path is refused and nothing is journaled through it"; else fail "a symbolic link at the rewrite journal's path is refused and nothing is journaled through it (rc=$rc: $out: $(cat "$TEST_ROOT/p16b.err"))"; fi
rm -f "$co_a16/.rewrite"
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c '^walk A$' "$wsa16/progress.md")" -eq 1 ] && [ "$(grep -c '^walk B$' "$wsa16/progress.md")" -eq 1 ] && [ ! -e "$co_a16/.rewrite/$(basename "$wsa16").journal" ]; then pass "with the link gone the rewrite completes, each line once"; else fail "with the link gone the rewrite completes, each line once (rc=$rc: $out)"; fi
# The scan over the incoming tree covers every path, not only plans/: a
# root-level .rewrite link plus plain files under plans/ would otherwise
# reach the checkout, and the next recovery would walk a planted journal
# through the link and write a forged line into a ledger.
make_pair p19
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b19="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa19=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa19/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
ws19=$(basename "$wsa19"); wsb19="$co_b19/plans/$ws19"
before19=$(git -C "$co_b19" hash-object "$wsb19/progress.md")
live19=$(wc -c < "$wsb19/progress.md" | tr -d ' ')
forged19="$TEST_ROOT/p19.staged"
cp "$wsb19/progress.md" "$forged19"
printf 'Task 99: complete (commits dead000..beef000, review clean)\n' >> "$forged19"
new19=$(wc -c < "$forged19" | tr -d ' ')
idx19="$TEST_ROOT/p19.index"
tip19=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
linkb19=$(printf 'plans/evil' | git -C "$PAIR_A" hash-object -w --stdin)
jb19=$(printf '%s %s plans/%s/progress.md\n' "$live19" "$new19" "$ws19" | git -C "$PAIR_A" hash-object -w --stdin)
sb19=$(git -C "$PAIR_A" hash-object -w "$forged19")
rm -f "$idx19"; GIT_INDEX_FILE=$idx19 git -C "$PAIR_A" read-tree "$tip19"
GIT_INDEX_FILE=$idx19 git -C "$PAIR_A" update-index --add --cacheinfo "120000,$linkb19,.rewrite"
GIT_INDEX_FILE=$idx19 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$jb19,plans/evil/$ws19.journal"
GIT_INDEX_FILE=$idx19 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$sb19,plans/evil/$ws19.staged"
tree19=$(GIT_INDEX_FILE=$idx19 git -C "$PAIR_A" write-tree)
evil19=$(printf 'a rewrite journal behind a root link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$tree19" -p "$tip19")
git -C "$PAIR_A" push -q origin "$evil19:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p19.out" 2> "$TEST_ROOT/p19.err"; rc=$?
out=$(cat "$TEST_ROOT/p19.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q '.rewrite' "$TEST_ROOT/p19.err" && [ ! -e "$co_b19/.rewrite" ] && [ ! -L "$co_b19/.rewrite" ]; then pass "a root-level link in the incoming tree is refused before checkout"; else fail "a root-level link in the incoming tree is refused before checkout (rc=$rc: $out: $(cat "$TEST_ROOT/p19.err"))"; fi
if [ "$(git -C "$co_b19" hash-object "$wsb19/progress.md")" = "$before19" ] && [ ! -f "$co_b19/.sync-applying" ] && [ "$(git -C "$co_b19" rev-parse hyperpowers/state)" = "$tip19" ]; then pass "the planted journal reaches nothing: the ledger, the marker and the ref are as they were"; else fail "the planted journal reaches nothing: the ledger, the marker and the ref are as they were ($(cat "$wsb19/progress.md" | tr '\n' '|'))"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(git -C "$co_b19" hash-object "$wsb19/progress.md")" = "$before19" ] && [ ! -f "$co_b19/.sync-applying" ]; then pass "a second sync refuses the same way with nothing half-applied"; else fail "a second sync refuses the same way with nothing half-applied (rc=$rc: $out)"; fi
# The same link on disk, whatever put it there: the recovery refuses before
# it walks the journals it would find through it.
make_pair p20
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b20="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa20=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa20/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
ws20=$(basename "$wsa20"); wsb20="$co_b20/plans/$ws20"
before20=$(git -C "$co_b20" hash-object "$wsb20/progress.md")
live20=$(wc -c < "$wsb20/progress.md" | tr -d ' ')
outside20="$TEST_ROOT/outside-p20"; mkdir -p "$outside20"
cp "$wsb20/progress.md" "$outside20/$ws20.staged"
printf 'Task 99: complete (commits dead000..beef000, review clean)\n' >> "$outside20/$ws20.staged"
new20=$(wc -c < "$outside20/$ws20.staged" | tr -d ' ')
printf '%s %s plans/%s/progress.md\n' "$live20" "$new20" "$ws20" > "$outside20/$ws20.journal"
ln -s "$outside20" "$co_b20/.rewrite"
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p20.out" 2> "$TEST_ROOT/p20.err"; rc=$?
out=$(cat "$TEST_ROOT/p20.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q '.rewrite' "$TEST_ROOT/p20.err"; then pass "recover_apply refuses a symlinked .rewrite on disk before walking its journals"; else fail "recover_apply refuses a symlinked .rewrite on disk before walking its journals (rc=$rc: $out: $(cat "$TEST_ROOT/p20.err"))"; fi
if [ "$(git -C "$co_b20" hash-object "$wsb20/progress.md")" = "$before20" ] && [ -f "$outside20/$ws20.journal" ] && [ -f "$outside20/$ws20.staged" ]; then pass "the ledger is untouched and the files behind the link are still there"; else fail "the ledger is untouched and the files behind the link are still there ($(cat "$wsb20/progress.md" | tr '\n' '|'))"; fi
rm -f "$co_b20/.rewrite"

echo ""
echo "=== a new ledger interrupted while it is created ==="
# A ledger absent at S is written with a plain append. Interrupted, it left
# a prefix that the next apply's ledger_apply extended with the whole blob
# (S has no blob to subtract), giving the ledger twice.
make_pair p17
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_b17="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa17=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa17/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
: > "$PAIR_A/docs/fresh.md"; git -C "$PAIR_A" add docs/fresh.md; git -C "$PAIR_A" commit -qm fresh; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
wsf17=$(run_sdd_dir "$PAIR_A" docs/fresh.md)
printf '# SDD ledger — plan: docs/fresh.md\nsession s-1: tasks 1,2\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' > "$wsf17/progress.md"
run_state "$PAIR_A" snapshot docs/fresh.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
wsf17_b="$co_b17/plans/$(basename "$wsf17")"
# The blob to compare against is read from the publishing host, before the
# interrupted apply can snapshot whatever it leaves over the target.
want17=$(git -C "$PAIR_A" rev-parse "hyperpowers/state:plans/$(basename "$wsf17")/progress.md")
( cd "$PAIR_B" && HYPERPOWERS_TEST_CRASH_AT=sync-mid-ledger-create bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && ls "$co_b17"/plans/*/*.new.* >/dev/null 2>&1 && [ ! -e "$wsf17_b/progress.md" ]; then pass "the seam stops halfway through creating a new ledger, with nothing published at its path"; else fail "the seam stops halfway through creating a new ledger, with nothing published at its path (rc=$rc)"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
have17=$(git -C "$co_b17" hash-object "$wsf17_b/progress.md" 2>/dev/null)
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=up-to-date" ] && [ -n "$want17" ] && [ "$have17" = "$want17" ]; then pass "the next sync leaves the new ledger byte-identical to the target blob, with nothing to snapshot over it"; else fail "the next sync leaves the new ledger byte-identical to the target blob, with nothing to snapshot over it (rc=$rc: $out: $(wc -c < "$wsf17_b/progress.md" | tr -d ' ') bytes)"; fi
if ! ls "$co_b17"/plans/*/*.new.* >/dev/null 2>&1 && [ -z "$(git -C "$co_b17" status --porcelain -- plans/)" ]; then pass "no temporary copy is left behind and the checkout is clean"; else fail "no temporary copy is left behind and the checkout is clean ($(git -C "$co_b17" status --porcelain -- plans/ | tr '\n' ' '))"; fi

echo ""
echo "=== a rewrite recovery a writer's line raced ==="
# The rewrite's presence test used to read the bytes at the recorded length.
# An unlocked writer's line can land exactly there between the crash and
# the recovery, and the extension was then appended a second time.
make_pair p18
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
co_a18="$STATE_ROOT/$(state_key "$PAIR_A")"; co_b18="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa18=$(run_sdd_dir "$PAIR_A" docs/plan.md); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa18/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; wsb18="$co_b18/plans/$(basename "$wsa18")"
# Leaves A positioned for a fast-forward onto B's merge, where the ledger
# is rewritten rather than appended to.
printf 'j6 A\n' >> "$wsa18/progress.md"; run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
printf 'j6 B\n' >> "$wsb18/progress.md"; run_state "$PAIR_B" snapshot docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null; git -C "$PAIR_B" push -q origin hyperpowers/state 2>/dev/null
( cd "$PAIR_A" && HYPERPOWERS_TEST_CRASH_AT=rewrite-after-journal bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -f "$co_a18/.rewrite/$(basename "$wsa18").journal" ] && [ "$(grep -c '^j6 B$' "$wsa18/progress.md")" -eq 0 ]; then pass "the crash seam after the journal leaves the ledger at the length it recorded"; else fail "the crash seam after the journal leaves the ledger at the length it recorded (rc=$rc)"; fi
# An unlocked writer appends exactly at that length, then the recovery is
# killed between its two writes.
printf 'raced the recovery\n' >> "$wsa18/progress.md"
( cd "$PAIR_A" && HYPERPOWERS_TEST_CRASH_AT=rewrite-after-extend bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc2=$?
# The last call finishes the rewrite. The apply itself stays unfinished
# after it, because the ledger now carries the writer's line between the
# target's two parts and no longer starts with what S committed; what this
# section is about is that the extension is not appended a second time.
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc3=$?
if [ "$rc2" -eq 99 ] && [ "$(grep -c '^j6 A$' "$wsa18/progress.md")" -eq 1 ]; then pass "the extension is appended once although a writer's line sits where it was expected"; else fail "the extension is appended once although a writer's line sits where it was expected (rc=$rc2/$rc3: $out: $(grep -c '^j6 A$' "$wsa18/progress.md") copies)"; fi
if [ "$(grep -c '^raced the recovery$' "$wsa18/progress.md")" -eq 1 ] && [ "$(grep -c '^j6 B$' "$wsa18/progress.md")" -eq 1 ] && [ ! -e "$co_a18/.rewrite/$(basename "$wsa18").journal" ] && [ ! -e "$co_a18/.rewrite/$(basename "$wsa18").staged" ]; then pass "the writer's line and the remote's line survive once each and the journal is gone"; else fail "the writer's line and the remote's line survive once each and the journal is gone ($(cat "$wsa18/progress.md" | tr '\n' '|'))"; fi

echo ""
echo "=== import recovery must not overwrite what the destination holds ==="
# The prefix recovery installs the legacy entries into a destination a
# controller is already working in: a report it revised must survive, and
# its ledger must be appended to, never replaced.
i19="$TEST_ROOT/i19"; make_repo "$i19"; mkdir -p "$i19/docs"; : > "$i19/docs/plan.md"; git -C "$i19" add docs; git -C "$i19" commit -qm plan
ws19=$(ws_path "$i19" "$i19/docs/plan.md"); mkdir -p "$ws19"
legacy19="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i19")/plans/$(basename "$ws19")"
mkdir -p "$legacy19.importing-558"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i19" > "$legacy19.importing-558/progress.md"
printf 'report one\n' > "$legacy19.importing-558/task-1-report.md"
printf 'report two\n' > "$legacy19.importing-558/task-2-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$ws19/progress.md"
printf 'report one, revised where the dossier lives now\n' > "$ws19/task-1-report.md"
out=$(run_state "$i19" import docs/plan.md 2> "$TEST_ROOT/i19.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy19 conflicts=1" ]; then pass "the recovery reports what it moved and how many entries it could not"; else fail "the recovery reports what it moved and how many entries it could not (rc=$rc: $out)"; fi
if [ "$(cat "$ws19/task-1-report.md")" = "report one, revised where the dossier lives now" ] && [ "$(cat "$ws19/task-1-report.md.from-import")" = "report one" ] && grep -q 'task-1-report.md.from-import' "$TEST_ROOT/i19.err"; then pass "a destination report the source also carries survives and the legacy copy is beside it"; else fail "a destination report the source also carries survives and the legacy copy is beside it ($(cat "$ws19/task-1-report.md"): $(cat "$TEST_ROOT/i19.err"))"; fi
if [ -f "$ws19/task-2-report.md" ] && [ "$(grep -c '^Task 2: complete' "$ws19/progress.md")" -eq 1 ] && [ "$(grep -c '^Task 1: complete' "$ws19/progress.md")" -eq 1 ] && [ "$(head -n 1 "$ws19/progress.md")" = "# SDD ledger — plan: docs/plan.md" ]; then pass "the entries the destination lacked are installed and the ledger keeps each line once"; else fail "the entries the destination lacked are installed and the ledger keeps each line once ($(cat "$ws19/progress.md" | tr '\n' '|'))"; fi
# A line written into the destination's ledger while the recovery runs:
# it is never replaced, and an abort leaves it where it was written.
i20="$TEST_ROOT/i20"; make_repo "$i20"; mkdir -p "$i20/docs"; : > "$i20/docs/plan.md"; git -C "$i20" add docs; git -C "$i20" commit -qm plan
ws20=$(ws_path "$i20" "$i20/docs/plan.md"); mkdir -p "$ws20"
legacy20="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i20")/plans/$(basename "$ws20")"
mkdir -p "$legacy20.importing-559"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i20" > "$legacy20.importing-559/progress.md"
printf 'report one\n' > "$legacy20.importing-559/task-1-report.md"
printf 'report two\n' > "$legacy20.importing-559/task-2-report.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$ws20/progress.md"
printf 'report one\n' > "$ws20/task-1-report.md"
out=$(cd "$i20" && HYPERPOWERS_TEST_DEST_APPEND='Task 9: complete (commits 7777777..8888888, review clean)' bash "$SDD_STATE" import docs/plan.md 2> "$TEST_ROOT/i20.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "${out%% *}" = "status=import-failed" ] && grep -q '^Task 9: complete' "$ws20/progress.md" && grep -q '^Task 1: complete' "$ws20/progress.md"; then pass "a ledger line written into the destination during the recovery is neither replaced nor deleted"; else fail "a ledger line written into the destination during the recovery is neither replaced nor deleted (rc=$rc: $out: $(cat "$ws20/progress.md" | tr '\n' '|'))"; fi
if grep -q 'kept its own ledger' "$TEST_ROOT/i20.err" && grep -q "progress.md for a human to merge" "$TEST_ROOT/i20.err" && ! grep -q 'nothing was moved' "$TEST_ROOT/i20.err"; then pass "the abort says the source-only files moved and names the ledger left for a human"; else fail "the abort says the source-only files moved and names the ledger left for a human ($(cat "$TEST_ROOT/i20.err"))"; fi
if [ -f "$legacy20/progress.md" ] && grep -q '^Task 2: complete' "$legacy20/progress.md" && ! ls -d "$legacy20.importing-"* >/dev/null 2>&1; then pass "the legacy source is put back whole for the next import"; else fail "the legacy source is put back whole for the next import"; fi

echo ""
echo "=== the new-ledger litter sweep is confined to its own name ==="
# The sweep clears a temporary copy of a ledger. A dossier file that merely
# carries .new. in its name is a controller's, and deleting it on every
# publishing call would take it off the branch.
make_pair p21
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
co_a21="$STATE_ROOT/$(state_key "$PAIR_A")"
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa21=$(run_sdd_dir "$PAIR_A" docs/plan.md)
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa21/progress.md"
printf 'notes a controller keeps\n' > "$wsa21/notes.new.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
out=$(run_state "$PAIR_A" sync docs/plan.md 2>/dev/null); rc=$?
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
if [ "$rc" -eq 0 ] && [ "${out%% *}" != "status=busy" ] && [ -f "$wsa21/notes.new.md" ] && [ "$(cat "$wsa21/notes.new.md")" = "notes a controller keeps" ]; then pass "a dossier file whose name holds .new. survives a sync and a snapshot"; else fail "a dossier file whose name holds .new. survives a sync and a snapshot (rc=$rc: $out)"; fi
if git -C "$co_a21" cat-file -e "refs/heads/hyperpowers/state:plans/$(basename "$wsa21")/notes.new.md" 2>/dev/null && [ -z "$(git -C "$co_a21" status --porcelain -- plans/)" ]; then pass "it stays tracked on the branch and the checkout is clean"; else fail "it stays tracked on the branch and the checkout is clean ($(git -C "$co_a21" status --porcelain -- plans/ | tr '\n' ' '))"; fi

echo ""
echo "=== import conflicts stay local to the host that found them ==="
# A copy beside a destination entry is for a human on this host to merge:
# the branch ignores it, and a regenerable entry gets no copy at all.
i21="$TEST_ROOT/i21"; make_repo "$i21"; mkdir -p "$i21/docs"; : > "$i21/docs/plan.md"; git -C "$i21" add docs; git -C "$i21" commit -qm plan
ws21=$(ws_path "$i21" "$i21/docs/plan.md"); mkdir -p "$ws21"
co21="$STATE_ROOT/$(state_key "$i21")"
legacy21="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$i21")/plans/$(basename "$ws21")"
mkdir -p "$legacy21.importing-560"
printf '# SDD ledger — plan: %s/docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' "$i21" > "$legacy21.importing-560/progress.md"
printf 'report one\n' > "$legacy21.importing-560/task-1-report.md"
printf 'brief one\n' > "$legacy21.importing-560/task-1-brief.md"
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$ws21/progress.md"
printf 'report one, revised where the dossier lives now\n' > "$ws21/task-1-report.md"
printf 'brief one, regenerated here\n' > "$ws21/task-1-brief.md"
out=$(run_state "$i21" import docs/plan.md 2> "$TEST_ROOT/i21.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=moved from=$legacy21 conflicts=2" ]; then pass "both conflicting entries are reported"; else fail "both conflicting entries are reported (rc=$rc: $out: $(cat "$TEST_ROOT/i21.err"))"; fi
if [ ! -e "$ws21/task-1-brief.md.from-import" ] && [ "$(cat "$ws21/task-1-brief.md")" = "brief one, regenerated here" ] && grep -q 'regenerable, not copied' "$TEST_ROOT/i21.err"; then pass "a regenerable entry the branch ignores gets no copy and is named as such"; else fail "a regenerable entry the branch ignores gets no copy and is named as such ($(cat "$TEST_ROOT/i21.err"))"; fi
run_state "$i21" snapshot docs/plan.md >/dev/null
if [ -f "$ws21/task-1-report.md.from-import" ] && git -C "$co21" check-ignore -q "plans/$(basename "$ws21")/task-1-report.md.from-import" && ! git -C "$co21" cat-file -e "refs/heads/hyperpowers/state:plans/$(basename "$ws21")/task-1-report.md.from-import" 2>/dev/null && [ -z "$(git -C "$co21" status --porcelain | grep -F '.from-import')" ]; then pass "a report's copy stays beside it, ignored by the branch, uncommitted and out of the status"; else fail "a report's copy stays beside it, ignored by the branch, uncommitted and out of the status ($(git -C "$co21" status --porcelain | tr '\n' ' '))"; fi

echo ""
echo "=== a hostile tree is refused before any of it reaches disk ==="
# The branch is foreign content. Every way a tree reaches this host is
# validated the same way: when the checkout is created at a tip, and when a
# commit is applied to an existing one.
# a. A fresh host whose tip carries the ledger as a link out of the cache.
make_pair p22
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa22=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws22=$(basename "$wsa22")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa22/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
outside22="$TEST_ROOT/outside-p22"; mkdir -p "$outside22"; printf 'untouched\n' > "$outside22/victim"
idx22="$TEST_ROOT/p22.index"; tip22=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
lb22=$(printf '%s' "$outside22/victim" | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx22"; GIT_INDEX_FILE=$idx22 git -C "$PAIR_A" read-tree "$tip22"
GIT_INDEX_FILE=$idx22 git -C "$PAIR_A" update-index --force-remove "plans/$ws22/progress.md"
GIT_INDEX_FILE=$idx22 git -C "$PAIR_A" update-index --add --cacheinfo "120000,$lb22,plans/$ws22/progress.md"
evil22=$(printf 'the ledger is a link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx22 git -C "$PAIR_A" write-tree)" -p "$tip22")
git -C "$PAIR_A" push -q origin "$evil22:refs/heads/hyperpowers/state" 2>/dev/null
co_b22="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p22.out" 2> "$TEST_ROOT/p22.err"; rc=$?
out=$(cat "$TEST_ROOT/p22.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'symbolic link' "$TEST_ROOT/p22.err" && grep -q "plans/$ws22/progress.md" "$TEST_ROOT/p22.err"; then pass "a tip whose ledger is a symbolic link is refused when the checkout would be created"; else fail "a tip whose ledger is a symbolic link is refused when the checkout would be created (rc=$rc: $out: $(cat "$TEST_ROOT/p22.err"))"; fi
if [ ! -e "$co_b22/.git" ] && ! ls -d "$co_b22".tmp-* >/dev/null 2>&1 && [ "$(cat "$outside22/victim")" = "untouched" ]; then pass "no checkout and no temporary one is left behind, and the link's target is untouched"; else fail "no checkout and no temporary one is left behind, and the link's target is untouched"; fi
rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan.md 2>/dev/null) || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(cat "$outside22/victim")" = "untouched" ]; then pass "sdd-dir on that host prints no path and exits 2"; else fail "sdd-dir on that host prints no path and exits 2 (rc=$rc: $out)"; fi
# b. A fresh host whose tip carries a recovery journal as plain files.
make_pair p23
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa23=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws23=$(basename "$wsa23")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa23/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
live23=$(wc -c < "$wsa23/progress.md" | tr -d ' ')
forged23="$TEST_ROOT/p23.staged"; cp "$wsa23/progress.md" "$forged23"
printf 'Task 99: complete (commits dead000..beef000, review clean)\n' >> "$forged23"
new23=$(wc -c < "$forged23" | tr -d ' ')
idx23="$TEST_ROOT/p23.index"; tip23=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
jb23=$(printf '%s %s plans/%s/progress.md\n' "$live23" "$new23" "$ws23" | git -C "$PAIR_A" hash-object -w --stdin)
sb23=$(git -C "$PAIR_A" hash-object -w "$forged23")
rm -f "$idx23"; GIT_INDEX_FILE=$idx23 git -C "$PAIR_A" read-tree "$tip23"
GIT_INDEX_FILE=$idx23 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$jb23,.rewrite/$ws23.journal"
GIT_INDEX_FILE=$idx23 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$sb23,.rewrite/$ws23.staged"
evil23=$(printf 'a journal in the tree\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx23 git -C "$PAIR_A" write-tree)" -p "$tip23")
git -C "$PAIR_A" push -q origin "$evil23:refs/heads/hyperpowers/state" 2>/dev/null
co_b23="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p23.out" 2> "$TEST_ROOT/p23.err"; rc=$?
out=$(cat "$TEST_ROOT/p23.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar' "$TEST_ROOT/p23.err"; then pass "a tip carrying a committed recovery journal is refused when the checkout would be created"; else fail "a tip carrying a committed recovery journal is refused when the checkout would be created (rc=$rc: $out: $(cat "$TEST_ROOT/p23.err"))"; fi
if [ ! -e "$co_b23/.git" ] && ! ls -d "$co_b23".tmp-* >/dev/null 2>&1 && ! grep -rq 'Task 99' "$co_b23" 2>/dev/null; then pass "no checkout is created and no ledger on this host holds the forged line"; else fail "no checkout is created and no ledger on this host holds the forged line"; fi
# c. The same pair of files arriving at a host that already has a checkout.
make_pair p24
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa24=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws24=$(basename "$wsa24")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa24/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b24="$STATE_ROOT/$(state_key "$PAIR_B")"; wsb24="$co_b24/plans/$ws24"
before24=$(git -C "$co_b24" hash-object "$wsb24/progress.md")
live24=$(wc -c < "$wsb24/progress.md" | tr -d ' ')
forged24="$TEST_ROOT/p24.staged"; cp "$wsb24/progress.md" "$forged24"
printf 'Task 99: complete (commits dead000..beef000, review clean)\n' >> "$forged24"
new24=$(wc -c < "$forged24" | tr -d ' ')
idx24="$TEST_ROOT/p24.index"; tip24=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
jb24=$(printf '%s %s plans/%s/progress.md\n' "$live24" "$new24" "$ws24" | git -C "$PAIR_A" hash-object -w --stdin)
sb24=$(git -C "$PAIR_A" hash-object -w "$forged24")
rm -f "$idx24"; GIT_INDEX_FILE=$idx24 git -C "$PAIR_A" read-tree "$tip24"
GIT_INDEX_FILE=$idx24 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$jb24,.rewrite/$ws24.journal"
GIT_INDEX_FILE=$idx24 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$sb24,.rewrite/$ws24.staged"
evil24=$(printf 'a journal in the tree\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx24 git -C "$PAIR_A" write-tree)" -p "$tip24")
git -C "$PAIR_A" push -q origin "$evil24:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p24.out" 2> "$TEST_ROOT/p24.err"; rc=$?
out=$(cat "$TEST_ROOT/p24.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar' "$TEST_ROOT/p24.err"; then pass "a committed recovery journal arriving by fast-forward is refused on apply"; else fail "a committed recovery journal arriving by fast-forward is refused on apply (rc=$rc: $out: $(cat "$TEST_ROOT/p24.err"))"; fi
if [ ! -f "$co_b24/.sync-applying" ] && [ ! -e "$co_b24/.rewrite" ] && [ "$(git -C "$co_b24" hash-object "$wsb24/progress.md")" = "$before24" ]; then pass "nothing is applied: no marker, no sidecar on disk, the ledger as it was"; else fail "nothing is applied: no marker, no sidecar on disk, the ledger as it was"; fi
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(git -C "$co_b24" hash-object "$wsb24/progress.md")" = "$before24" ]; then pass "a second sync refuses it the same way"; else fail "a second sync refuses it the same way (rc=$rc: $out)"; fi
# d. A checkout created before this fix, whose HEAD already tracks the pair.
make_pair p25
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa25=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws25=$(basename "$wsa25")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa25/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
co_a25="$STATE_ROOT/$(state_key "$PAIR_A")"
before25=$(git -C "$co_a25" hash-object "$wsa25/progress.md")
live25=$(wc -c < "$wsa25/progress.md" | tr -d ' ')
mkdir -p "$co_a25/.rewrite"
cp "$wsa25/progress.md" "$co_a25/.rewrite/$ws25.staged"
printf 'Task 99: complete (commits dead000..beef000, review clean)\n' >> "$co_a25/.rewrite/$ws25.staged"
new25=$(wc -c < "$co_a25/.rewrite/$ws25.staged" | tr -d ' ')
printf '%s %s plans/%s/progress.md\n' "$live25" "$new25" "$ws25" > "$co_a25/.rewrite/$ws25.journal"
git -C "$co_a25" add -f .rewrite >/dev/null 2>&1
git -C "$co_a25" -c user.name=t -c user.email=t@example.com commit -qm "a sidecar on the branch" >/dev/null 2>&1
run_state "$PAIR_A" snapshot docs/plan.md > "$TEST_ROOT/p25.out" 2> "$TEST_ROOT/p25.err"; rc=$?
out=$(cat "$TEST_ROOT/p25.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar' "$TEST_ROOT/p25.err"; then pass "a snapshot refuses to run recovery from files the branch tracks"; else fail "a snapshot refuses to run recovery from files the branch tracks (rc=$rc: $out: $(cat "$TEST_ROOT/p25.err"))"; fi
out=$(run_state "$PAIR_A" sync docs/plan.md 2>"$TEST_ROOT/p25b.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar' "$TEST_ROOT/p25b.err"; then pass "sync refuses the same tracked sidecar"; else fail "sync refuses the same tracked sidecar (rc=$rc: $out: $(cat "$TEST_ROOT/p25b.err"))"; fi
if [ "$(git -C "$co_a25" hash-object "$wsa25/progress.md")" = "$before25" ] && [ -f "$co_a25/.rewrite/$ws25.journal" ] && [ -f "$co_a25/.rewrite/$ws25.staged" ]; then pass "the ledger is unchanged and the tracked journal is neither run nor removed"; else fail "the ledger is unchanged and the tracked journal is neither run nor removed ($(cat "$wsa25/progress.md" | tr '\n' '|'))"; fi
# e. A submodule entry inside a workspace.
make_pair p26
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa26=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws26=$(basename "$wsa26")
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsa26/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
co_b26="$STATE_ROOT/$(state_key "$PAIR_B")"
idx26="$TEST_ROOT/p26.index"; tip26=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
rm -f "$idx26"; GIT_INDEX_FILE=$idx26 git -C "$PAIR_A" read-tree "$tip26"
GIT_INDEX_FILE=$idx26 git -C "$PAIR_A" update-index --add --cacheinfo "160000,$tip26,plans/$ws26/vendor"
evil26=$(printf 'a submodule in a workspace\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx26 git -C "$PAIR_A" write-tree)" -p "$tip26")
git -C "$PAIR_A" push -q origin "$evil26:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p26.out" 2> "$TEST_ROOT/p26.err"; rc=$?
out=$(cat "$TEST_ROOT/p26.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'submodule entry' "$TEST_ROOT/p26.err" && [ ! -e "$co_b26/plans/$ws26/vendor" ]; then pass "a submodule entry inside a workspace is refused and never materialized"; else fail "a submodule entry inside a workspace is refused and never materialized (rc=$rc: $out: $(cat "$TEST_ROOT/p26.err"))"; fi
# f. A plain-backend host, where git archive writes the tip's entries
# straight into the plain cache. Nothing inspected that tree, so the link
# landed; sdd-dir then refused the workspace it had just written, and the
# remedy it printed could not clear the tip it keeps re-extracting.
make_pair p27
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
wsa27=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws27=$(basename "$wsa27")
# Host B fails its worktree add once, against a branch that holds no
# workspace yet: backend=plain is recorded and nothing is materialized.
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
keyb27=$(state_key "$PAIR_B"); plainb27="$XDG_CACHE_HOME/hyperpowers/sdd/$keyb27"
out=$(cd "$PAIR_B" && HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 bash "$SDD_DIR" docs/plan.md 2>/dev/null)
if [ "$out" = "$plainb27/plans/$ws27" ] && [ "$(head -n1 "$STATE_ROOT/$keyb27.backend")" = plain ]; then pass "the plain host records its backend before the branch carries the plan"; else fail "the plain host records its backend before the branch carries the plan ($out)"; fi
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa27/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
outside27="$TEST_ROOT/outside-p27"; mkdir -p "$outside27"; printf 'untouched\n' > "$outside27/victim"
idx27="$TEST_ROOT/p27.index"; tip27=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
lb27=$(printf '%s' "$outside27/victim" | git -C "$PAIR_A" hash-object -w --stdin)
rb27=$(git -C "$PAIR_A" rev-parse "hyperpowers/state:plans/$ws27/progress.md")
rm -f "$idx27"; GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" read-tree "$tip27"
GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" update-index --force-remove "plans/$ws27/progress.md"
GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" update-index --add --cacheinfo "120000,$lb27,plans/$ws27/progress.md"
evil27=$(printf 'the ledger is a link\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" write-tree)" -p "$tip27")
git -C "$PAIR_A" push -q origin "$evil27:refs/heads/hyperpowers/state" 2>/dev/null
# The host fetches for itself: sync returns on the backend file alone.
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
out=$(run_state "$PAIR_B" sync docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=plain" ]; then pass "sync on the plain host reports the backend"; else fail "sync on the plain host reports the backend (rc=$rc: $out)"; fi
rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan.md 2> "$TEST_ROOT/p27.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'symbolic link' "$TEST_ROOT/p27.err" && grep -q "plans/$ws27/progress.md" "$TEST_ROOT/p27.err" && grep -q 'hyperpowers/state' "$TEST_ROOT/p27.err"; then pass "the plain fallback refuses a tip whose ledger is a symbolic link, naming the branch to repair"; else fail "the plain fallback refuses a tip whose ledger is a symbolic link, naming the branch to repair (rc=$rc: $out: $(cat "$TEST_ROOT/p27.err"))"; fi
if [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27.err")" -eq 1 ]; then pass "a specific refusal is the only sdd-dir line on stderr"; else fail "a specific refusal is the only sdd-dir line on stderr ($(grep -c '^sdd-dir:' "$TEST_ROOT/p27.err") lines)"; fi
if [ -z "$(find "$plainb27" -type l 2>/dev/null)" ] && ! ls -d "$plainb27"/.materialize.* >/dev/null 2>&1 && [ "$(cat "$outside27/victim")" = "untouched" ]; then pass "no link and no staging directory reach the plain cache, and the link's target is untouched"; else fail "no link and no staging directory reach the plain cache, and the link's target is untouched ($(find "$plainb27" -type l 2>/dev/null | tr '\n' ' '))"; fi
# The remedy it prints is reachable: the branch gets the regular file back.
rm -f "$idx27"; GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" read-tree "$evil27"
GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" update-index --force-remove "plans/$ws27/progress.md"
GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$rb27,plans/$ws27/progress.md"
fixed27=$(printf 'the ledger is a file again\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx27 git -C "$PAIR_A" write-tree)" -p "$evil27")
git -C "$PAIR_A" push -q origin "$fixed27:refs/heads/hyperpowers/state" 2>/dev/null
git -C "$PAIR_B" fetch -q origin "+refs/heads/hyperpowers/state:refs/remotes/origin/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null
rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan.md 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$plainb27/plans/$ws27" ] && [ ! -L "$out/progress.md" ] && [ "$(sed -n 2p "$out/progress.md")" = "Task 1: complete (commits 1111111..2222222, review clean)" ]; then pass "with the link replaced on the branch the same call materializes the workspace"; else fail "with the link replaced on the branch the same call materializes the workspace (rc=$rc: $out)"; fi
# A second plan, to exercise the publish itself. This host's state branch is
# behind origin (the forged tips above were pushed straight to it), so A
# syncs before it snapshots: an unsynced push is rejected and the tip B reads
# would never carry the plan.
: > "$PAIR_A/docs/plan2.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan2; git -C "$PAIR_A" push -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan2.md >/dev/null
wsa27b=$(run_sdd_dir "$PAIR_A" docs/plan2.md); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsa27b/progress.md"
run_state "$PAIR_A" snapshot docs/plan2.md >/dev/null; git -C "$PAIR_A" push -q origin hyperpowers/state 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null; git -C "$PAIR_B" fetch -q origin hyperpowers/state 2>/dev/null
plain27="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$PAIR_B")"; ws27b=$(basename "$wsa27b")
# The materialization above recorded its source in the backend file, which
# the checks below read for a source no failed call may write.
printf 'plain\n' > "$STATE_ROOT/$(state_key "$PAIR_B").backend"
# The destination reappears after it was cleared: the publish refuses rather
# than nesting the staged copy inside it, and nothing is recorded.
rc=0; out=$(HYPERPOWERS_TEST_WRITER_AT="materialize-before-publish:$ws27b" run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27c.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27c.err")" -eq 1 ] && grep -q 'could not materialize' "$TEST_ROOT/p27c.err" && [ ! -e "$plain27/plans/$ws27b/$ws27b" ] && [ ! -f "$plain27/plans/$ws27b/progress.md" ] && [ -f "$plain27/plans/$ws27b/stray" ] && ! grep -q "source=" "$STATE_ROOT/$(state_key "$PAIR_B").backend"; then pass "a destination that reappears right before the rename is refused, not nested, its contents kept, and nothing recorded"; else fail "a destination that reappears right before the rename is refused (rc=$rc; $(tr '\n' '|' < "$TEST_ROOT/p27c.err"))"; fi
# The occupied destination is never cleared by the helper: a human removes
# it, and the next call materializes.
rm -rf "$plain27/plans/$ws27b"
out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$out/progress.md" ]; then pass "once the occupied destination is cleared the next call materializes the same plan"; else fail "once the occupied destination is cleared the next call materializes (rc=$rc: $out)"; fi
rm -rf "$plain27/plans/$ws27b"; printf 'plain\n' > "$STATE_ROOT/$(state_key "$PAIR_B").backend"
# A destination that already holds something (no ledger) before the call is
# refused with its contents intact; an empty one is replaced.
mkdir -p "$plain27/plans/$ws27b"; printf 'theirs\n' > "$plain27/plans/$ws27b/notes.txt"
rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27d.err") || rc=$?
if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(cat "$plain27/plans/$ws27b/notes.txt")" = "theirs" ] && [ ! -f "$plain27/plans/$ws27b/progress.md" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27d.err")" -eq 1 ] && ! grep -q "source=" "$STATE_ROOT/$(state_key "$PAIR_B").backend"; then pass "a destination that already holds files is refused with every byte intact"; else fail "a destination that already holds files is refused with every byte intact (rc=$rc: $out)"; fi
rm -f "$plain27/plans/$ws27b/notes.txt"
out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -f "$out/progress.md" ]; then pass "an empty pre-existing destination is replaced by the publish"; else fail "an empty pre-existing destination is replaced by the publish (rc=$rc: $out)"; fi
rm -rf "$plain27/plans/$ws27b"; printf 'plain\n' > "$STATE_ROOT/$(state_key "$PAIR_B").backend"
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$plain27/plans"; chmod 0555 "$plain27"
  rc=0; out=$(run_sdd_dir "$PAIR_B" docs/plan2.md 2> "$TEST_ROOT/p27b.err") || rc=$?
  chmod 0755 "$plain27"
  if [ "$rc" -eq 2 ] && [ -z "$out" ] && [ "$(grep -c '^sdd-dir:' "$TEST_ROOT/p27b.err")" -eq 1 ] && grep -q 'could not materialize' "$TEST_ROOT/p27b.err"; then pass "an unreported materialization failure gets exactly one generic sdd-dir line"; else fail "an unreported materialization failure gets exactly one generic sdd-dir line (rc=$rc; $(tr '\n' '|' < "$TEST_ROOT/p27b.err"))"; fi
else
  pass "an unreported materialization failure gets exactly one generic sdd-dir line (skipped: root ignores directory modes)"
fi
# g. A root blob at a sidecar's own name. A tree at .restore/ was already
# refused; a blob at exactly .restore passed, reached disk, and had the
# next recover_apply refuse every publishing subcommand on the sidecar the
# branch tracks. All three routes a tree takes to disk refuse it.
make_pair p28
mkdir -p "$PAIR_A/docs"; : > "$PAIR_A/docs/plan.md"; git -C "$PAIR_A" add docs; git -C "$PAIR_A" commit -qm plan; git -C "$PAIR_A" push -q origin main 2>/dev/null
git -C "$PAIR_B" pull -q origin main 2>/dev/null
run_state "$PAIR_A" sync docs/plan.md >/dev/null
wsa28=$(run_sdd_dir "$PAIR_A" docs/plan.md); ws28=$(basename "$wsa28")
printf '# SDD ledger — plan: docs/plan.md\nTask 1: complete (commits 1111111..2222222, review clean)\n' > "$wsa28/progress.md"
run_state "$PAIR_A" snapshot docs/plan.md >/dev/null
clean28=$(git -C "$PAIR_A" rev-parse hyperpowers/state)
idx28="$TEST_ROOT/p28.index"
bb28=$(printf 'a restore copy the branch carries\n' | git -C "$PAIR_A" hash-object -w --stdin)
rm -f "$idx28"; GIT_INDEX_FILE=$idx28 git -C "$PAIR_A" read-tree "$clean28"
GIT_INDEX_FILE=$idx28 git -C "$PAIR_A" update-index --add --cacheinfo "100644,$bb28,.restore"
evil28=$(printf 'the restore sidecar as a root blob\n' | git -C "$PAIR_A" -c user.name=t -c user.email=t@example.com commit-tree "$(GIT_INDEX_FILE=$idx28 git -C "$PAIR_A" write-tree)" -p "$clean28")
git -C "$PAIR_A" push -q origin "$evil28:refs/heads/hyperpowers/state" 2>/dev/null
co_b28="$STATE_ROOT/$(state_key "$PAIR_B")"
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p28.out" 2> "$TEST_ROOT/p28.err"; rc=$?
out=$(cat "$TEST_ROOT/p28.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar at \.restore' "$TEST_ROOT/p28.err" && [ ! -e "$co_b28/.git" ] && [ ! -e "$co_b28/.restore" ]; then pass "a root blob at .restore is refused when the checkout would be created"; else fail "a root blob at .restore is refused when the checkout would be created (rc=$rc: $out: $(cat "$TEST_ROOT/p28.err"))"; fi
# The same blob arriving by fast-forward at a host that already has a checkout.
git -C "$PAIR_A" push -q -f origin "$clean28:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md >/dev/null 2>&1
wsb28="$co_b28/plans/$ws28"; before28=$(git -C "$co_b28" hash-object "$wsb28/progress.md")
git -C "$PAIR_A" push -q origin "$evil28:refs/heads/hyperpowers/state" 2>/dev/null
run_state "$PAIR_B" sync docs/plan.md > "$TEST_ROOT/p28b.out" 2> "$TEST_ROOT/p28b.err"; rc=$?
out=$(cat "$TEST_ROOT/p28b.out")
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q 'recovery sidecar at \.restore' "$TEST_ROOT/p28b.err" && [ ! -e "$co_b28/.restore" ] && [ ! -f "$co_b28/.sync-applying" ] && [ "$(git -C "$co_b28" hash-object "$wsb28/progress.md")" = "$before28" ]; then pass "a root blob at .restore arriving by fast-forward is refused on apply, with nothing written"; else fail "a root blob at .restore arriving by fast-forward is refused on apply (rc=$rc: $out: $(cat "$TEST_ROOT/p28b.err"))"; fi
# And on the plain backend, where git archive would write it straight into
# the cache. The remote tip B just fetched carries the blob.
plain28="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$PAIR_B")"
err=$(materialize "$PAIR_B" "$ws28" "$plain28/plans/$ws28" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'recovery sidecar at .restore' && [ ! -e "$plain28/plans/$ws28" ] && [ ! -e "$plain28/.restore" ]; then pass "a root blob at .restore is refused before the plain fallback extracts the tip"; else fail "a root blob at .restore is refused before the plain fallback extracts the tip (rc=$rc: $err)"; fi
echo "deps: the plan graph and the overlap check"
make_repo "$TEST_ROOT/dp"; dp="$TEST_ROOT/dp"
mkdir -p "$dp/docs"
cat > "$dp/docs/plan.md" <<'PLAN'
# Plan

**Spec:** docs/spec.md

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`

### Task 1: A

**Risk tier:** standard

**Depends on:** none

**Files:**
- Create: `src/a.sh`
- Test: `tests/t.sh`

**Interfaces:**
- Produces: `a_fn`

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

**Files:**
- Modify: `src/b.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `a_fn`

### Task 3: C

**Risk tier:** standard

**Depends on:** none

**Files:**
- Modify: `tests/t.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `a_fn`
PLAN
git -C "$dp" add docs; git -C "$dp" commit -qm plan
out=$(run_state "$dp" deps docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=deps tasks=3" ] && [ "$(printf '%s\n' "$out" | sed -n 2,4p | tr '\n' '|')" = "task=1 depends=none|task=2 depends=1|task=3 depends=none|" ]; then pass "deps prints the graph in heading order with a plan= blob"; else fail "deps prints the graph (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$dp" deps docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=conflicts count=2" ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,3 shares=tests/t.sh' && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,3 interface=a_fn direction=consumer-first' && ! printf '%s\n' "$out" | grep -q 'CHANGELOG'; then pass "deps --check names a shared Test path and a consumer without an edge, and skips a merge-expected file"; else fail "deps --check conflicts (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
printf 'scan: accepted-overlap tasks=1,3 path=tests/t.sh\nscan: accepted-overlap tasks=1,3 interface=a_fn\n' > "$TEST_ROOT/dp.ledger"
out=$(run_state "$dp" deps docs/plan.md --check --ledger "$TEST_ROOT/dp.ledger" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=clean" ]; then pass "accepted overlaps from the ledger are suppressed"; else fail "accepted overlaps suppressed (rc=$rc: $out)"; fi
# A legacy plan: no Depends on lines at all, serial by default.
sed '/^\*\*Depends on:\*\*/d' "$dp/docs/plan.md" > "$dp/docs/legacy.md"; git -C "$dp" add docs; git -C "$dp" commit -qm legacy
out=$(run_state "$dp" deps docs/legacy.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 2,4p | tr '\n' '|')" = "task=1 depends=none|task=2 depends=1|task=3 depends=1,2|" ]; then pass "a plan without Depends on lines is serial"; else fail "legacy serial default (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# Mixed annotation, a cycle, an unknown task, a self-dependency, a duplicate heading: each exit 2 with its line.
# awk, not sed '0,/re/': BSD sed has no 0,/re/ address and would leave the plan unchanged.
awk '/^\*\*Depends on:\*\* none$/ && !dropped { dropped = 1; next } { print }' "$dp/docs/plan.md" > "$dp/docs/mixed.md"
err=$(run_state "$dp" deps --from docs/mixed.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'mixed annotation: tasks without a Depends on line: 1'; then pass "mixed annotation is a parse error naming the task"; else fail "mixed annotation (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* none$/**Depends on:** Task 2/' "$dp/docs/plan.md" | awk 'BEGIN{n=0} /^\*\*Depends on:\*\* Task 2$/{n++; if(n==2){print "**Depends on:** none"; next}} {print}' > "$dp/docs/cycle.md"
err=$(run_state "$dp" deps --from docs/cycle.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'cycle: '; then pass "a cycle is a parse error"; else fail "cycle (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* Task 1$/**Depends on:** Task 9/' "$dp/docs/plan.md" > "$dp/docs/unknown.md"
err=$(run_state "$dp" deps --from docs/unknown.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'unknown task: 9 (from task 2)'; then pass "an unknown dependency is a parse error"; else fail "unknown task (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* Task 1$/**Depends on:** Task 2/' "$dp/docs/plan.md" > "$dp/docs/self.md"
err=$(run_state "$dp" deps --from docs/self.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'self-dependency: task 2'; then pass "a self-dependency is a parse error"; else fail "self-dependency (rc=$rc: $err)"; fi
sed 's/^### Task 3: C$/### Task 2: C/' "$dp/docs/plan.md" > "$dp/docs/dup.md"
err=$(run_state "$dp" deps --from docs/dup.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'duplicate heading: task 2'; then pass "a duplicated heading is a parse error"; else fail "duplicate heading (rc=$rc: $err)"; fi
# Fenced blocks are text: an implementation plan embeds fixture plans, and their headings are not tasks.
cp "$dp/docs/plan.md" "$dp/docs/fenced.md"
cat >> "$dp/docs/fenced.md" <<'FENCED'

### Task 4: D

**Risk tier:** standard

**Depends on:** none

**Files:**
- Create: `src/d.sh`

- [ ] **Step 1: A fixture plan inside a fence**

```bash
cat > plan.md <<'EOF'
### Task 9: Ghost

**Depends on:** Task 1

**Files:**
- Modify: `src/a.sh`
EOF
```

~~~
### Task 10: Ghost
~~~
FENCED
out=$(run_state "$dp" deps --from docs/fenced.md docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f3)" = "tasks=4" ] && ! printf '%s\n' "$out" | grep -q 'task=9\|task=10'; then pass "headings and Depends on lines inside fenced blocks are not tasks"; else fail "fenced headings (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$dp" deps --from docs/fenced.md docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=conflicts count=2" ]; then pass "a Files block inside a fence adds no overlap"; else fail "fenced Files block (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# The authoritative plan is the plan ref's head, not the working copy.
printf '\n### Task 4: D\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n**Files:**\n- Create: `src/d.sh`\n' >> "$dp/docs/plan.md"
out=$(run_state "$dp" deps docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f3)" = "tasks=3" ]; then pass "deps reads the committed plan, not the working copy"; else fail "deps reads the ref (rc=$rc: $(printf '%s' "$out" | sed -n 1p))"; fi
git -C "$dp" checkout -q -- docs/plan.md
# A path with a space is printed percent-encoded, so a space-splitting reader keeps one field, and the ledger carries the same form.
cat > "$dp/docs/spaced.md" <<'SPACED'
### Task 1: A

**Depends on:** none

**Files:**
- Modify: `docs/design notes.md`

### Task 2: B

**Depends on:** none

**Files:**
- Modify: `docs/design notes.md`
SPACED
out=$(run_state "$dp" deps --from docs/spaced.md docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,2 shares=docs/design%20notes.md'; then pass "a shared path with a space is printed percent-encoded"; else fail "encoded shares path (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
printf 'scan: accepted-overlap tasks=1,2 path=docs/design%%20notes.md\n' > "$TEST_ROOT/dp-space.ledger"
out=$(run_state "$dp" deps --from docs/spaced.md docs/plan.md --check --ledger "$TEST_ROOT/dp-space.ledger" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=clean" ]; then pass "an accepted overlap carrying the encoded path is suppressed"; else fail "encoded accepted overlap (rc=$rc: $out)"; fi

# A malformed dependency line is an error, never a normalized guess: a typo must not erase a prerequisite.
dep_bad() { # <name> <awk program rewriting plan.md> <expected stderr fragment>
  awk "$2" "$dp/docs/plan.md" > "$dp/docs/$1.md"
  err=$(run_state "$dp" deps --from "docs/$1.md" docs/plan.md 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$3"; then pass "dependency line: $1 is a parse error"; else fail "dependency line $1 (rc=$rc: $err)"; fi
}
dep_bad blank '/^\*\*Depends on:\*\* Task 1$/ { print "**Depends on:**"; next } { print }' 'malformed dependency line: task 2: '
dep_bad bare '/^\*\*Depends on:\*\* Task 1$/ { print "**Depends on:** Task"; next } { print }' 'malformed dependency line: task 2: Task'
dep_bad nocomma '/^\*\*Depends on:\*\* Task 1$/ { print "**Depends on:** Task 1 Task 2"; next } { print }' 'malformed dependency line: task 2: Task 1 Task 2'
dep_bad repeated '/^\*\*Depends on:\*\* Task 1$/ { print "**Depends on:** Task 1, Task 1"; next } { print }' 'malformed dependency line: task 2: Task 1, Task 1'
# A heading that starts like a task but breaks the grammar is an error: it must not drop the task or carry text into its id.
dep_bad headtext '/^### Task 2:/ { print "### Task 2:x"; next } { print }' 'malformed task heading: ### Task 2:x'
dep_bad headsub '/^### Task 2:/ { print "### Task 2:$(true)"; next } { print }' 'malformed task heading: ### Task 2:$(true)'
dep_bad twice '/^\*\*Depends on:\*\* Task 1$/ { print; print ""; print "**Depends on:** none"; next } { print }' 'malformed dependency line: task 2: none'
# The Global Constraints scope ends at the first task heading, so a task's prose cannot widen the allowlist.
cat > "$dp/docs/gcscope.md" <<'GCSCOPE'
# Plan

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`

### Task 1: A

**Depends on:** none

The **Merge-expected files:** `src/shared.sh` note here is prose.

**Files:**
- Modify: `src/shared.sh`

### Task 2: B

**Depends on:** none

**Files:**
- Modify: `src/shared.sh`
GCSCOPE
out=$(run_state "$dp" deps --from docs/gcscope.md docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,2 shares=src/shared.sh'; then pass "task prose cannot extend the merge-expected list"; else fail "constraints scope (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# Only the first backticked span of a Files line is a path; the rest is annotation.
cat > "$dp/docs/annot.md" <<'ANNOT'
### Task 1: A

**Depends on:** none

**Files:**
- Modify: `src/a.sh` (new functions after `helper_fn`, `:186`)

### Task 2: B

**Depends on:** none

**Files:**
- Modify: `src/b.sh` (new functions after `helper_fn`, `:186`)
ANNOT
out=$(run_state "$dp" deps --from docs/annot.md docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=clean" ]; then pass "annotation spans on a Files line are not paths"; else fail "annotated Files lines (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# The plan id and the plan text come from one object even when the branch moves between them.
make_repo "$TEST_ROOT/dr"; dr="$TEST_ROOT/dr"; mkdir -p "$dr/docs"
printf '### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** none\n' > "$dr/docs/plan.md"
git -C "$dr" add docs; git -C "$dr" commit -qm old; old_sha=$(git -C "$dr" rev-parse HEAD)
printf '\n### Task 3: C\n\n**Depends on:** none\n' >> "$dr/docs/plan.md"
git -C "$dr" commit -qam new; new_blob=$(git -C "$dr" rev-parse HEAD:docs/plan.md)
out=$(HYPERPOWERS_TEST_WRITER_AT="deps-after-resolve:$old_sha" run_state "$dr" deps docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "status=deps plan=${new_blob:0:7} tasks=3" ]; then pass "a branch moved after the id is resolved does not change the plan read"; else fail "plan id and text from one object (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi

# --from is read from the caller's directory, and its hash is of that same file.
mkdir -p "$TEST_ROOT/elsewhere/docs"
# deps resolves the cwd's repository as the code repository, so the caller's directory must be one.
git init -q "$TEST_ROOT/elsewhere"
printf '### Task 1: A\n\n**Depends on:** none\n' > "$TEST_ROOT/elsewhere/docs/only-here.md"
out=$(cd "$TEST_ROOT/elsewhere" && bash "$SDD_STATE" deps --from docs/only-here.md "$dp/docs/plan.md" 2>/dev/null); rc=$?
want=$(git -C "$dp" hash-object "$TEST_ROOT/elsewhere/docs/only-here.md")
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "status=deps plan=${want:0:7} tasks=1" ]; then pass "--from outside the plan repository hashes the file it parsed"; else fail "--from relative to another cwd (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
printf '### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** none\n' > "$dp/docs/candidate.md"
printf '### Task 1: A\n\n**Depends on:** none\n' > "$TEST_ROOT/elsewhere/docs/candidate.md"
out=$(cd "$TEST_ROOT/elsewhere" && bash "$SDD_STATE" deps --from docs/candidate.md "$dp/docs/plan.md" 2>/dev/null); rc=$?
want=$(git -C "$dp" hash-object "$TEST_ROOT/elsewhere/docs/candidate.md")
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "status=deps plan=${want:0:7} tasks=1" ]; then pass "a same-named file in the plan repository does not stand in for the caller's --from"; else fail "same-named --from (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
echo "register: the plan line, siblings and the lock pair"
make_pair rg; rg_a=$PAIR_A
mkdir -p "$rg_a/docs"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan.md"; : > "$rg_a/docs/spec.md"
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan2.md"
git -C "$rg_a" add docs; git -C "$rg_a" commit -qm plans; git -C "$rg_a" push -q origin main 2>/dev/null
git -C "$rg_a" switch -q -c feat
run_state "$rg_a" sync docs/plan.md >/dev/null 2>&1; wsr=$(run_sdd_dir "$rg_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsr/progress.md"
out=$(run_state "$rg_a" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ] && grep -q "^plan: integration feat code-root [0-9a-f]\{7\} plan-ref feat plan-root [0-9a-f]\{7\} spec docs/spec.md$" "$wsr/progress.md"; then pass "register writes the plan line once"; else fail "register writes the plan line (rc=$rc: $out: $(grep '^plan:' "$wsr/progress.md" 2>/dev/null))"; fi
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ] && [ "$(grep -c '^plan: integration' "$wsr/progress.md")" = 1 ]; then pass "a matching re-registration is a no-op"; else fail "matching re-registration (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration other 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ]; then pass "a different branch for a registered plan is wrong-branch"; else fail "wrong-branch (rc=$rc: $out)"; fi
wsr2=$(run_sdd_dir "$rg_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsr2/progress.md"
out=$(run_state "$rg_a" register docs/plan2.md --session s3 --integration feat2 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% plan=*}" = "status=spec-branch-mismatch expected=feat" ] && [ "${out##* plan=}" = "$(basename "$wsr")" ]; then pass "a sibling plan of the same spec must share the integration branch"; else fail "spec-branch-mismatch (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" register docs/plan2.md --session s3 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "a sibling on the same branch registers"; else fail "sibling registers (rc=$rc: $out)"; fi
# verify: a named branch that is neither the integration branch nor a task branch.
git -C "$rg_a" switch -q -c stray
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ]; then pass "verify reports wrong-branch on a stray branch"; else fail "verify wrong-branch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q -c "feat.$(basename "$wsr" | sed 's/.*-//').task-1" feat
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=ok" ]; then pass "verify accepts this plan's task branch"; else fail "verify task branch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q --detach feat
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "verify accepts a detached checkout"; else fail "verify detached (rc=$rc: $out)"; fi
# A later session registers detached (the plan ref comes from the plan line) or from this plan's task branch; a first registration needs a named branch.
out=$(run_state "$rg_a" register docs/plan.md --session s9 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ]; then pass "a later session registers from a detached checkout"; else fail "detached re-registration (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q "feat.$(basename "$wsr" | sed 's/.*-//').task-1"
out=$(run_state "$rg_a" register docs/plan.md --session s9 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "a session on this plan's task branch re-registers"; else fail "task-branch re-registration (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q --detach feat
printf '# T\n\n**Spec:** docs/spec3.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan3.md"; : > "$rg_a/docs/spec3.md"
wsr3=$(run_sdd_dir "$rg_a" docs/plan3.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan3.md\n' > "$wsr3/progress.md"
out=$(run_state "$rg_a" register docs/plan3.md --session s9 --integration feat3 2>/dev/null); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=detached-head repo=plan" ] && ! grep -q '^plan:' "$wsr3/progress.md"; then pass "a first registration needs a named branch to name the plan ref"; else fail "detached first registration (rc=$rc: $out)"; fi
rm -rf "$wsr3"; rm -f "$rg_a/docs/plan3.md" "$rg_a/docs/spec3.md"
git -C "$rg_a" switch -q feat
make_repo "$TEST_ROOT/foreign"
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat --code-repo "$TEST_ROOT/foreign" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "register refuses a code repository whose root is not the recorded code root"; else fail "register wrong-repo (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" deps docs/plan.md --code-repo "$TEST_ROOT/foreign" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "deps refuses a foreign --code-repo once the plan line exists"; else fail "deps wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign" && bash "$SDD_STATE" deps "$rg_a/docs/plan.md" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "deps run from a foreign repository without --code-repo is wrong-repo"; else fail "deps foreign cwd (rc=$rc: $out)"; fi
# A re-registration must match the whole plan line: the plan ref and the plan root too.
git -C "$rg_a" switch -q -c feat-b feat
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat repo=plan" ]; then pass "a plan repository on another branch than the recorded plan ref is wrong-branch repo=plan"; else fail "plan-ref mismatch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q feat
pl_orig=$(grep '^plan: integration' "$wsr/progress.md")
sed -i '' 's| plan-root [0-9a-f]* spec | plan-root 0000000 spec |' "$wsr/progress.md" 2>/dev/null || sed -i 's| plan-root [0-9a-f]* spec | plan-root 0000000 spec |' "$wsr/progress.md"
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=0000000 repo=plan" ]; then pass "a recorded plan root that is not this repository's is wrong-repo repo=plan"; else fail "plan-root mismatch (rc=$rc: $out)"; fi
sed -i '' "s|^plan: integration .*|$pl_orig|" "$wsr/progress.md" 2>/dev/null || sed -i "s|^plan: integration .*|$pl_orig|" "$wsr/progress.md"
# The plan in one repository and the code in another: the state lives with the plan, the plan line records both roots.
make_repo "$TEST_ROOT/sp"; make_repo "$TEST_ROOT/sc"; sp="$TEST_ROOT/sp"; sc="$TEST_ROOT/sc"
# Two repositories made in the same second would share a root commit id, and the root is what identifies the code repository.
git -C "$sc" commit -q --amend --allow-empty -m "code root"
mkdir -p "$sp/docs"; printf '# S\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$sp/docs/plan.md"; : > "$sp/docs/spec.md"; git -C "$sp" add docs; git -C "$sp" commit -qm plan; git -C "$sp" switch -q -c plans
git -C "$sc" switch -q -c feat
wssp=$(run_sdd_dir "$sp" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wssp/progress.md"
root_sc=$(git -C "$sc" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7); root_sp=$(git -C "$sp" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7)
out=$(cd "$sc" && bash "$SDD_STATE" register "$sp/docs/plan.md" --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=plans" ] && grep -q "^plan: integration feat code-root $root_sc plan-ref plans plan-root $root_sp spec docs/spec.md$" "$wssp/progress.md"; then pass "a split layout records the code root from the cwd and the plan ref from the plan repository"; else fail "split register (rc=$rc: $out: $(grep '^plan:' "$wssp/progress.md" 2>/dev/null))"; fi
out=$(run_state "$sp" register docs/plan.md --session s2 --integration feat --code-repo "$sc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=plans" ]; then pass "a re-registration from the plan repository with --code-repo matches"; else fail "split re-register (rc=$rc: $out)"; fi
out=$(run_state "$sp" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "the plan repository itself is not the code repository"; else fail "split wrong-repo (rc=$rc: $out)"; fi
# A spec path with a space and a plan file name with a space: the plan line keeps the path as written, comparisons and status fields are percent-encoded.
make_pair sp2; sq_a=$PAIR_A
mkdir -p "$sq_a/docs"; : > "$sq_a/docs/design notes.md"
printf '# P\n\n**Spec:** docs/design notes.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$sq_a/docs/plan.md"
printf '# Q\n\n**Spec:** docs/design notes.md\n\n### Task 1: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$sq_a/docs/old plan.md"
git -C "$sq_a" add docs; git -C "$sq_a" commit -qm plans; git -C "$sq_a" switch -q -c feat
run_state "$sq_a" sync docs/plan.md >/dev/null 2>&1
sq1=$(run_sdd_dir "$sq_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$sq1/progress.md"
sq2=$(run_sdd_dir "$sq_a" "docs/old plan.md" 2>/dev/null); printf '# SDD ledger — plan: docs/old plan.md\n' > "$sq2/progress.md"
out=$(run_state "$sq_a" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && grep -q '^plan: integration feat code-root [0-9a-f]\{7\} plan-ref feat plan-root [0-9a-f]\{7\} spec docs/design notes.md$' "$sq1/progress.md"; then pass "a spec path with a space is written as the header has it"; else fail "spaced spec register (rc=$rc: $out: $(grep '^plan:' "$sq1/progress.md"))"; fi
out=$(run_state "$sq_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ]; then pass "a plan with a spaced spec path re-registers"; else fail "spaced spec re-register (rc=$rc: $out)"; fi
out=$(run_state "$sq_a" register "docs/old plan.md" --session s3 --integration feat2 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% plan=*}" = "status=spec-branch-mismatch expected=feat" ] && [ "${out##* plan=}" = "$(basename "$sq1")" ]; then pass "a sibling of a spaced spec on another branch is spec-branch-mismatch"; else fail "spaced spec sibling (rc=$rc: $out)"; fi
out=$(run_state "$sq_a" register "docs/old plan.md" --session s3 --integration feat 2>/dev/null); rc=$?
# Only the spaced workspace is registered now, so the mismatch must name it.
sed -i '' '/^plan: integration/d' "$sq1/progress.md" 2>/dev/null || sed -i '/^plan: integration/d' "$sq1/progress.md"
out=$(run_state "$sq_a" register docs/plan.md --session s4 --integration feat2 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out##* plan=}" = "$(basename "$sq2" | sed 's/ /%20/g')" ] && [ "${out##* plan=}" != "$(basename "$sq2")" ]; then pass "the plan= field names a spaced workspace percent-encoded"; else fail "spaced workspace encoding (rc=$rc: $out)"; fi
# register guards: a mistyped integration branch, a missing one, links, shallow clones and look-alike specs.
reg_repo() { # <path> <spec name>: a plan repository on branch feat with a ledger; prints the workspace
  make_repo "$1"; mkdir -p "$1/docs"
  printf '# P\n\n**Spec:** docs/%s\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' "$2" > "$1/docs/plan.md"; : > "$1/docs/$2"
  git -C "$1" add docs; git -C "$1" commit -qm plan; git -C "$1" switch -q -c feat
  run_state "$1" sync docs/plan.md >/dev/null 2>&1
  local w; w=$(run_sdd_dir "$1" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$w/progress.md"; printf '%s\n' "$w"
}
ty=$TEST_ROOT/ty; wty=$(reg_repo "$ty" spec.md)
out=$(run_state "$ty" register docs/plan.md --session s1 --integration typo 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ] && ! grep -q '^plan:' "$wty/progress.md"; then pass "a mistyped integration branch on one repository is wrong-branch and writes nothing"; else fail "typo integration (rc=$rc: $out)"; fi
mc=$TEST_ROOT/mc; make_repo "$mc"
out=$(cd "$mc" && bash "$SDD_STATE" register "$ty/docs/plan.md" --session s1 --integration nothere 2>"$TEST_ROOT/ty.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -q "the integration branch nothere does not exist" "$TEST_ROOT/ty.err" && ! grep -q '^plan:' "$wty/progress.md"; then pass "an integration branch missing from the code repository is an error and writes nothing"; else fail "missing integration branch (rc=$rc: $out)"; fi
# A workspace or a ledger replaced by a link is never written through.
mkdir -p "$TEST_ROOT/outside"; printf '# SDD ledger — plan: docs/plan.md\n' > "$TEST_ROOT/outside/progress.md"; cp "$TEST_ROOT/outside/progress.md" "$TEST_ROOT/outside/progress.orig"
rm -rf "$wty"; ln -s "$TEST_ROOT/outside" "$wty"
out=$(run_state "$ty" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && cmp -s "$TEST_ROOT/outside/progress.md" "$TEST_ROOT/outside/progress.orig"; then pass "a workspace replaced by a link is refused and the referent is untouched"; else fail "workspace link (rc=$rc: $out)"; fi
rm -f "$wty"; wty=$(run_sdd_dir "$ty" docs/plan.md 2>/dev/null); rm -f "$wty/progress.md"; ln -s "$TEST_ROOT/outside/progress.md" "$wty/progress.md"
out=$(run_state "$ty" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && cmp -s "$TEST_ROOT/outside/progress.md" "$TEST_ROOT/outside/progress.orig"; then pass "a ledger replaced by a link is refused and the referent is untouched"; else fail "ledger link (rc=$rc: $out)"; fi
# A shallow clone's root is a fetch boundary: register refuses it until it is unshallowed.
make_repo "$TEST_ROOT/shsrc"; git -C "$TEST_ROOT/shsrc" commit -q --allow-empty -m two; mkdir -p "$TEST_ROOT/shsrc/docs"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$TEST_ROOT/shsrc/docs/plan.md"; : > "$TEST_ROOT/shsrc/docs/spec.md"; git -C "$TEST_ROOT/shsrc" add docs; git -C "$TEST_ROOT/shsrc" commit -qm three
git clone -q --depth 1 "file://$TEST_ROOT/shsrc" "$TEST_ROOT/shc" 2>/dev/null; git -C "$TEST_ROOT/shc" switch -q -c feat
run_state "$TEST_ROOT/shc" sync docs/plan.md >/dev/null 2>&1; wshc=$(run_sdd_dir "$TEST_ROOT/shc" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wshc/progress.md"
out=$(run_state "$TEST_ROOT/shc" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=shallow-source repo=code" ] && ! grep -q '^plan:' "$wshc/progress.md"; then pass "a shallow code repository is refused"; else fail "shallow code (rc=$rc: $out)"; fi
git clone -q --depth 1 "file://$TEST_ROOT/shsrc" "$TEST_ROOT/shp" 2>/dev/null
run_state "$TEST_ROOT/shp" sync docs/plan.md >/dev/null 2>&1; wshp=$(run_sdd_dir "$TEST_ROOT/shp" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wshp/progress.md"
make_repo "$TEST_ROOT/shk"; git -C "$TEST_ROOT/shk" switch -q -c feat
out=$(cd "$TEST_ROOT/shk" && bash "$SDD_STATE" register "$TEST_ROOT/shp/docs/plan.md" --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=shallow-source repo=plan" ] && ! grep -q '^plan:' "$wshp/progress.md"; then pass "a shallow plan repository in a split layout is refused"; else fail "shallow plan (rc=$rc: $out)"; fi
git -C "$TEST_ROOT/shc" fetch -q --unshallow 2>/dev/null
out=$(run_state "$TEST_ROOT/shc" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "after an unshallow the same registration succeeds"; else fail "unshallowed register (rc=$rc: $out)"; fi
# Specs that differ only by a literal %20 are different specs.
make_repo "$TEST_ROOT/dd"; mkdir -p "$TEST_ROOT/dd/docs"
printf '# P\n\n**Spec:** docs/a b.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$TEST_ROOT/dd/docs/pa.md"
printf '# P\n\n**Spec:** docs/a%%20b.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$TEST_ROOT/dd/docs/pb.md"
git -C "$TEST_ROOT/dd" add docs; git -C "$TEST_ROOT/dd" commit -qm plans; git -C "$TEST_ROOT/dd" switch -q -c feat
for pn in pa pb; do run_state "$TEST_ROOT/dd" sync docs/$pn.md >/dev/null 2>&1; w=$(run_sdd_dir "$TEST_ROOT/dd" docs/$pn.md 2>/dev/null); printf '# SDD ledger — plan: docs/%s.md\n' "$pn" > "$w/progress.md"; done
out=$(run_state "$TEST_ROOT/dd" register docs/pa.md --session s1 --integration feat 2>/dev/null); rc1=$?
git -C "$TEST_ROOT/dd" switch -q -c feat2 feat
out2=$(run_state "$TEST_ROOT/dd" register docs/pb.md --session s2 --integration feat2 2>/dev/null); rc2=$?
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ]; then pass "specs docs/a b.md and docs/a%20b.md are not siblings"; else fail "look-alike specs (rc $rc1 $rc2: $out / $out2)"; fi
# Linked worktrees of one repository are one repository: the plan ref must still be the integration branch.
lw=$TEST_ROOT/lw; wlw=$(reg_repo "$lw" spec.md)
git -C "$lw" worktree add -q "$TEST_ROOT/lw-linked" -b other 2>/dev/null
out=$(run_state "$lw" register docs/plan.md --session s1 --integration other --code-repo "$TEST_ROOT/lw-linked" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ] && ! grep -q '^plan:' "$wlw/progress.md"; then pass "a linked worktree of the plan repository is the same repository: a mismatched integration is wrong-branch"; else fail "linked worktree mismatch (rc=$rc: $out)"; fi
out=$(run_state "$lw" register docs/plan.md --session s1 --integration feat --code-repo "$TEST_ROOT/lw-linked" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && grep -q '^plan: integration feat code-root [0-9a-f]\{7\} plan-ref feat ' "$wlw/progress.md"; then pass "the same call with the plan's branch registers"; else fail "linked worktree register (rc=$rc: $out: $(grep '^plan:' "$wlw/progress.md"))"; fi
git -C "$lw" worktree remove --force "$TEST_ROOT/lw-linked" 2>/dev/null
# Two sibling registrations with different branches through a barrier: exactly one succeeds.
git -C "$rg_a" switch -q feat
rm -rf "$wsr2"; wsr2=$(run_sdd_dir "$rg_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsr2/progress.md"
sed -i '' '/^plan: integration/d' "$wsr/progress.md" 2>/dev/null || sed -i '/^plan: integration/d' "$wsr/progress.md"
co_r=$(dirname "$(dirname "$wsr")")
: > "$co_r/.register-before-write-pause"
( cd "$rg_a" && HYPERPOWERS_TEST_PAUSE_AT=register-before-write bash "$SDD_STATE" register docs/plan.md --session s1 --integration feat > "$TEST_ROOT/rg.1" 2>/dev/null; echo $? > "$TEST_ROOT/rg.1rc" ) &
n=0; while [ ! -e "$co_r/.register-before-write-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
( cd "$rg_a" && bash "$SDD_STATE" register docs/plan2.md --session s3 --integration feat2 > "$TEST_ROOT/rg.2" 2>/dev/null; echo $? > "$TEST_ROOT/rg.2rc" ) &
sleep 0.5; rm -f "$co_r/.register-before-write-pause"; wait
r1=$(cat "$TEST_ROOT/rg.1rc"); r2=$(cat "$TEST_ROOT/rg.2rc")
if { [ "$r1" = 0 ] && [ "$r2" = 9 ]; } || { [ "$r1" = 9 ] && [ "$r2" = 0 ]; }; then pass "two sibling registrations with different branches: exactly one succeeds"; else fail "registration race (rcs $r1 $r2: $(cat "$TEST_ROOT/rg.1") / $(cat "$TEST_ROOT/rg.2"))"; fi
# The lock pair in ascending key order, roles swapped between two operations.
make_repo "$TEST_ROOT/lk1"; make_repo "$TEST_ROOT/lk2"
# HP_LOCK_DIR2 is the first-taken (lower-key) lock. The pause files make the barrier real: without them the first holder would finish before the second starts.
for lkr in lk1 lk2; do : > "$( . "$LIB"; hp_checkout_path "$TEST_ROOT/$lkr" ).lock-pair-between-pause"; done
( . "$LIB"; HYPERPOWERS_TEST_PAUSE_AT=lock-pair-between hp_lock_pair "$TEST_ROOT/lk1" "$TEST_ROOT/lk2" > /dev/null 2>&1; echo "$HP_LOCK_DIR2" > "$TEST_ROOT/lk.first"; hp_unlock ) &
sleep 0.3
( . "$LIB"; hp_lock_pair "$TEST_ROOT/lk2" "$TEST_ROOT/lk1" > /dev/null 2>&1; echo "$HP_LOCK_DIR2" > "$TEST_ROOT/lk.second"; hp_unlock ) &
sleep 0.3; rm -f "$XDG_CACHE_HOME"/hyperpowers/state/*.lock-pair-between-pause 2>/dev/null; wait
k1=$(state_key "$TEST_ROOT/lk1"); k2=$(state_key "$TEST_ROOT/lk2"); lower=$k1; [ "$k1" \< "$k2" ] || lower=$k2
if [ "$(basename "$(cat "$TEST_ROOT/lk.first")" .lock)" = "$lower" ] && [ "$(basename "$(cat "$TEST_ROOT/lk.second")" .lock)" = "$lower" ]; then pass "hp_lock_pair takes the lower key first whichever role each repository plays"; else fail "lock pair order ($(cat "$TEST_ROOT/lk.first") / $(cat "$TEST_ROOT/lk.second") lower=$lower)"; fi

echo "claim: dependencies and branches"
make_pair cl; cl_a=$PAIR_A
mkdir -p "$cl_a/docs"; : > "$cl_a/docs/spec.md"
cat > "$cl_a/docs/plan.md" <<'PLAN'
# P

**Spec:** docs/spec.md

### Task 1: A

**Risk tier:** standard

**Depends on:** none

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

### Task 3: C

**Risk tier:** standard

**Depends on:** none

### Task 4: D

**Risk tier:** standard

**Depends on:** none
PLAN
git -C "$cl_a" add docs; git -C "$cl_a" commit -qm plan; git -C "$cl_a" push -q origin main 2>/dev/null; git -C "$cl_a" switch -q -c feat
run_state "$cl_a" sync docs/plan.md >/dev/null 2>&1; wscl=$(run_sdd_dir "$cl_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wscl/progress.md"
run_state "$cl_a" register docs/plan.md --session s1 --integration feat >/dev/null
ws8cl=$(basename "$wscl" | sed 's/.*-//'); H0=$(git -C "$cl_a" rev-parse feat)
make_repo "$TEST_ROOT/foreign-cl"
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 --code-repo "$TEST_ROOT/foreign-cl" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ ! -d "$wscl/claims/task-1" ]; then pass "a claim refuses a foreign code repository before writing"; else fail "claim wrong-repo (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "${out%% plan=*}" = "status=blocked task=2 waiting=1" ] && [ ! -d "$wscl/claims/task-2" ]; then pass "a task whose predecessor is incomplete is blocked and nothing is written"; else fail "blocked (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=feat.$ws8cl.task-1 from=${H0:0:7}" ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-1")" = "$H0" ] && grep -q "^Task 1: branch feat.$ws8cl.task-1 from ${H0:0:7}$" "$wscl/progress.md" && grep -q "^branch=feat.$ws8cl.task-1$" "$wscl/claims/task-1/owner" && [ -f "$wscl/activity/s1" ]; then pass "a claim creates the task branch at the integration head, records it and stamps activity"; else fail "claim creates the branch (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=1 owner=s1 own=1 branch=feat.$ws8cl.task-1 from=${H0:0:7}" ]; then pass "the owner's re-claim repeats the branch"; else fail "own re-claim (rc=$rc: $out)"; fi
# A crash after the rename: the retry creates the branch and the line.
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s1 2>/dev/null); rc=$?
git -C "$cl_a" branch -D "feat.$ws8cl.task-3" >/dev/null 2>&1; sed -i '' '/^Task 3: branch/d' "$wscl/progress.md" 2>/dev/null || sed -i '/^Task 3: branch/d' "$wscl/progress.md"
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% owner=*}" = "status=held task=3" ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-3" >/dev/null && grep -q '^Task 3: branch' "$wscl/progress.md"; then pass "the owner's retry completes a missing branch and ledger line"; else fail "own retry completes (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wscl/progress.md"
( cd "$cl_a" && HYPERPOWERS_TEST_CRASH_AT=claim-after-rename bash "$SDD_STATE" claim docs/plan.md 2 --session s1 >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -d "$wscl/claims/task-2" ] && ! git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-2" >/dev/null; then pass "the crash seam stops after the rename with no branch yet"; else fail "crash after rename (rc=$rc)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 2 --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && ! git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-2" >/dev/null; then pass "a losing claimant creates no branch"; else fail "loser no branch (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-2" >/dev/null && grep -q '^Task 2: branch' "$wscl/progress.md"; then pass "the retry after the crash finishes the claim"; else fail "retry after crash (rc=$rc: $out)"; fi
# A crash after the branch: the branch exists, the ledger line is owed; the retry appends it.
( cd "$cl_a" && HYPERPOWERS_TEST_CRASH_AT=claim-after-branch bash "$SDD_STATE" claim docs/plan.md 4 --session s1 >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-4" >/dev/null && ! grep -q '^Task 4: branch' "$wscl/progress.md"; then pass "the crash seam after the branch leaves the ledger line owed"; else fail "crash after branch (rc=$rc)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 4 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% owner=*}" = "status=held task=4" ] && grep -q "^Task 4: branch feat.$ws8cl.task-4 from " "$wscl/progress.md"; then pass "the retry after the branch crash appends the line"; else fail "retry after branch crash (rc=$rc: $out)"; fi
# A losing claimant creates no branch; a takeover gets task-N.2 from the old head.
# The dead session's work sits on the task branch, ahead of the integration branch.
wk=$(git -C "$cl_a" commit-tree -p "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3")" -m "work on 3" "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3^{tree}")"); git -C "$cl_a" update-ref "refs/heads/feat.$ws8cl.task-3" "$wk"
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s2 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% from=*}" = "status=claimed task=3 takeover=1 branch=feat.$ws8cl.task-3.2" ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3.2")" = "$wk" ] && [ "$wk" != "$(git -C "$cl_a" rev-parse feat)" ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-3" >/dev/null; then pass "a takeover branches task-3.2 from the old branch head, not the integration head, and leaves the old branch"; else fail "takeover branch (rc=$rc: $out)"; fi
# Two sibling plans both claiming Task 1 create distinct branches.
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: Z\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$cl_a/docs/plan2.md"; git -C "$cl_a" add docs; git -C "$cl_a" commit -qm plan2
wscl2=$(run_sdd_dir "$cl_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wscl2/progress.md"; run_state "$cl_a" register docs/plan2.md --session s3 --integration feat >/dev/null
out=$(run_state "$cl_a" claim docs/plan2.md 1 --session s3 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out#*branch=}" != "${out#*branch=feat.$ws8cl.}" ] && git -C "$cl_a" rev-parse -q --verify "feat.$(basename "$wscl2" | sed 's/.*-//').task-1" >/dev/null; then pass "sibling plans' Task 1 branches carry their own ws8"; else fail "sibling branch names (rc=$rc: $out)"; fi
# A plan without a plan line keeps today's claim: no branch.
make_repo "$TEST_ROOT/cl0"; mkdir -p "$TEST_ROOT/cl0/docs"; printf '# P\n\n### Task 1: A\n\n**Risk tier:** standard\n' > "$TEST_ROOT/cl0/docs/plan.md"; git -C "$TEST_ROOT/cl0" add docs; git -C "$TEST_ROOT/cl0" commit -qm plan
ws0=$(ws_path "$TEST_ROOT/cl0" "$TEST_ROOT/cl0/docs/plan.md"); mkdir -p "$ws0"; printf '# SDD ledger — plan: docs/plan.md\n' > "$ws0/progress.md"
out=$(run_state "$TEST_ROOT/cl0" claim docs/plan.md 1 --session s9 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=none" ]; then pass "a claim without a plan line creates no branch"; else fail "no plan line (rc=$rc: $out)"; fi
# Review fixtures: pre-upgrade owner records, containment, takeover retry, leftovers.
printf '# R\n\n**Spec:** docs/spec.md\n' > "$cl_a/docs/plan3.md"
for t in 1 2 3 4 5 6 7 8 9; do printf '\n### Task %s: T\n\n**Risk tier:** standard\n\n**Depends on:** none\n' "$t" >> "$cl_a/docs/plan3.md"; done
git -C "$cl_a" add docs; git -C "$cl_a" commit -qm plan3
wscl3=$(run_sdd_dir "$cl_a" docs/plan3.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan3.md\n' > "$wscl3/progress.md"; run_state "$cl_a" register docs/plan3.md --session s4 --integration feat >/dev/null
ws83=$(basename "$wscl3" | sed 's/.*-//'); H3=$(git -C "$cl_a" rev-parse feat)
mkdir -p "$wscl3/claims/task-2" "$wscl3/claims/task-3"
for t in 2 3; do printf 'session=sold\nworktree=%s\nbranch=main\nhost=h\ntime=2026-01-01T00:00:00Z\n' "$cl_a" > "$wscl3/claims/task-$t/owner"; done
out=$(run_state "$cl_a" claim docs/plan3.md 2 --session sold 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=2 owner=sold own=1 branch=none" ]; then pass "an owner's re-claim of a pre-upgrade record has no task branch"; else fail "pre-upgrade own (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan3.md 3 --session s5 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws83.task-3.2")" = "$H3" ]; then pass "a takeover of a pre-upgrade record branches from the integration head"; else fail "pre-upgrade takeover (rc=$rc: $out)"; fi
# A takeover retried after a crash between the record and the branch.
run_state "$cl_a" claim docs/plan3.md 1 --session s4 >/dev/null 2>&1
wk1=$(git -C "$cl_a" commit-tree -p "$H3" -m "work on 1" "$(git -C "$cl_a" rev-parse "feat^{tree}")"); git -C "$cl_a" update-ref "refs/heads/feat.$ws83.task-1" "$wk1"
run_state "$cl_a" claim docs/plan3.md 1 --session s5 --takeover >/dev/null 2>&1
git -C "$cl_a" branch -D "feat.$ws83.task-1.2" >/dev/null 2>&1; sed -i '' '/^Task 1: branch feat.[0-9a-f]*.task-1.2 /d' "$wscl3/progress.md" 2>/dev/null || sed -i '/^Task 1: branch .*task-1.2 /d' "$wscl3/progress.md"
out=$(run_state "$cl_a" claim docs/plan3.md 1 --session s5 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% from=*}" = "status=held task=1 owner=s5 own=1 branch=feat.$ws83.task-1.2" ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws83.task-1.2")" = "$wk1" ] && ! git -C "$cl_a" rev-parse -q --verify "feat.$ws83.task-1.3" >/dev/null && [ "$(grep -c '^--- superseded' "$wscl3/claims/task-1/owner.history")" = 1 ]; then pass "a retried takeover completes at the recorded base without superseding itself"; else fail "takeover retry (rc=$rc: $out)"; fi
# A leftover branch past its base makes a fresh claim an error that names it.
wk4=$(git -C "$cl_a" commit-tree -p "$H3" -m leftover "$(git -C "$cl_a" rev-parse "feat^{tree}")"); git -C "$cl_a" update-ref "refs/heads/feat.$ws83.task-4" "$wk4"
out=$(run_state "$cl_a" claim docs/plan3.md 4 --session s4 2>&1); rc=$?
case "$out" in *"feat.$ws83.task-4 already exists"*"status=error"*) lf=1 ;; *) lf=0 ;; esac
out2=$(run_state "$cl_a" claim docs/plan3.md 4 --session s4 2>&1); rc2=$?
if [ "$rc" -eq 2 ] && [ "$lf" = 1 ] && [ ! -d "$wscl3/claims/task-4" ] && [ "$rc2" -eq 2 ] && [ "$out2" = "$out" ]; then pass "a fresh claim refuses a leftover task branch before publishing, every time"; else fail "leftover branch (rc=$rc/$rc2: $out)"; fi
# Containment: a hostile session id cannot reach the ledger, a symlinked activity directory receives nothing.
cp "$wscl3/progress.md" "$TEST_ROOT/ledger3.before"
out=$(run_state "$cl_a" claim docs/plan3.md 5 --session ../progress.md 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out##*$'\n'}" = "status=error" ] && grep -q '^# SDD ledger' "$wscl3/progress.md" && cmp -s "$wscl3/progress.md" <(cat "$TEST_ROOT/ledger3.before"; grep '^Task 5: branch' "$wscl3/progress.md"); then pass "a session id with .. cannot overwrite the ledger"; else fail "hostile session id (rc=$rc: $out)"; fi
mkdir -p "$TEST_ROOT/outside-activity"; rm -rf "$wscl3/activity"; ln -s "$TEST_ROOT/outside-activity" "$wscl3/activity"
out=$(run_state "$cl_a" claim docs/plan3.md 6 --session s4 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ -z "$(ls "$TEST_ROOT/outside-activity")" ]; then pass "an activity symlink receives no write"; else fail "activity symlink (rc=$rc: $out)"; fi
rm -f "$wscl3/activity"
# The temporary name is exclusive: a planted link at <sid>.new is never followed, and a link at the final path is refused.
mkdir -p "$wscl3/activity"; printf keep > "$TEST_ROOT/victim-new"; ln -s "$TEST_ROOT/victim-new" "$wscl3/activity/s4.new"
out=$(run_state "$cl_a" claim docs/plan3.md 7 --session s4 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$TEST_ROOT/victim-new")" = keep ] && [ -f "$wscl3/activity/s4" ] && [ ! -L "$wscl3/activity/s4" ]; then pass "a planted link at the old temporary name is not followed"; else fail "planted .new link (rc=$rc: $out)"; fi
printf keep > "$TEST_ROOT/victim-final"; ln -s "$TEST_ROOT/victim-final" "$wscl3/activity/s7"
out=$(run_state "$cl_a" claim docs/plan3.md 8 --session s7 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out##*$'\n'}" = "status=error" ] && [ "$(cat "$TEST_ROOT/victim-final")" = keep ]; then pass "a link at the final activity path is refused and its target is unchanged"; else fail "final activity link (rc=$rc: $out)"; fi
rm -f "$wscl3/activity/s7"
# An existing claim answers held even after an amendment adds an incomplete predecessor; only a takeover is blocked.
run_state "$cl_a" claim docs/plan3.md 9 --session s4 >/dev/null 2>&1
sed '$d' "$cl_a/docs/plan3.md" > "$TEST_ROOT/plan3.amend"; printf '**Depends on:** Task 8\n' >> "$TEST_ROOT/plan3.amend"
cp "$TEST_ROOT/plan3.amend" "$cl_a/docs/plan3.md"; git -C "$cl_a" add docs; git -C "$cl_a" commit -qm amend
out=$(run_state "$cl_a" claim docs/plan3.md 9 --session s4 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% branch=*}" = "status=held task=9 owner=s4 own=1" ]; then pass "the owner's re-claim stays held after an amendment adds a predecessor"; else fail "amended own (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan3.md 9 --session s6 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && [ "${out%% since=*}" = "status=held task=9 owner=s4" ]; then pass "a competitor's claim stays held after an amendment adds a predecessor"; else fail "amended competitor (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan3.md 9 --session s6 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "${out%% plan=*}" = "status=blocked task=9 waiting=8" ] && [ "$(sed -n 's/^session=//p' "$wscl3/claims/task-9/owner")" = s4 ]; then pass "a takeover is blocked by the new predecessor and the owner is unchanged"; else fail "amended takeover (rc=$rc: $out)"; fi
# Recovery can bring in the registered ledger: the claim settles the plan line after recovery.
make_pair ra; ra_a=$PAIR_A; ra_b=$PAIR_B
mkdir -p "$ra_a/docs"; : > "$ra_a/docs/spec.md"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$ra_a/docs/plan.md"
git -C "$ra_a" add docs; git -C "$ra_a" commit -qm plan; git -C "$ra_a" push -q origin main 2>/dev/null
run_state "$ra_a" sync docs/plan.md >/dev/null 2>&1; git -C "$ra_a" push -q origin hyperpowers/state 2>/dev/null; git -C "$ra_b" pull -q origin main 2>/dev/null; run_state "$ra_b" sync docs/plan.md >/dev/null 2>&1
wsra=$(run_sdd_dir "$ra_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsra/progress.md"
run_state "$ra_a" register docs/plan.md --session s1 --integration main >/dev/null 2>&1
run_state "$ra_a" snapshot docs/plan.md >/dev/null 2>&1; git -C "$ra_a" push -q origin hyperpowers/state 2>/dev/null
( cd "$ra_b" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
ws8ra=$(basename "$wsra" | sed 's/.*-//'); Hra=$(git -C "$ra_b" rev-parse main)
out=$(run_state "$ra_b" claim docs/plan.md 1 --session s2 2>/dev/null); rcc=$?
if [ "$rc" -eq 99 ] && [ "$rcc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=main.$ws8ra.task-1 from=${Hra:0:7}" ] && git -C "$ra_b" rev-parse -q --verify "main.$ws8ra.task-1" >/dev/null; then pass "a claim that recovery brings a plan line to takes the pair and creates the branch"; else fail "recovery brings plan line (rc=$rc/$rcc: $out)"; fi
# Without a plan line a parse error still refuses; only a plan with no headings stays claimable.
mkplan() { # <name> <plan text>: a repository whose ledger has no plan line
  make_repo "$TEST_ROOT/$1"; mkdir -p "$TEST_ROOT/$1/docs"; printf '%s' "$2" > "$TEST_ROOT/$1/docs/plan.md"
  git -C "$TEST_ROOT/$1" add docs; git -C "$TEST_ROOT/$1" commit -qm plan
  MP_WS=$(ws_path "$TEST_ROOT/$1" "$TEST_ROOT/$1/docs/plan.md"); mkdir -p "$MP_WS"; printf '# SDD ledger — plan: docs/plan.md\n' > "$MP_WS/progress.md"
}
mkplan ev1 $'# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n'
out=$(run_state "$TEST_ROOT/ev1" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out%% plan=*}" = "status=invalid" ] && [ ! -d "$MP_WS/claims/task-1" ]; then pass "without a plan line a mixed-annotation plan refuses and writes nothing"; else fail "mixed annotation (rc=$rc: $out)"; fi
mkplan ev2 $'# P\n\n### Task 1: A\n'
out=$(run_state "$TEST_ROOT/ev2" claim docs/plan.md 5 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -d "$MP_WS/claims/task-5" ]; then pass "without a plan line a task the graph lacks refuses"; else fail "task not in plan (rc=$rc: $out)"; fi
mkplan ev3 ''
out=$(run_state "$TEST_ROOT/ev3" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=none" ]; then pass "an empty plan still claims without a dependency check"; else fail "empty plan (rc=$rc: $out)"; fi
# Completion is a line that begins with the marker, not a mention inside another line.
mkplan ev4 $'# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** Task 1\n'
printf 'plan: amended abc1234 by s1: Task 1: complete\nscan: accepted-overlap x: Task 1: complete\n' >> "$MP_WS/progress.md"
out=$(run_state "$TEST_ROOT/ev4" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=none" ]; then pass "the done check ignores a mention inside an amendment or scan line"; else fail "done ignores mentions (rc=$rc: $out)"; fi
out=$(run_state "$TEST_ROOT/ev4" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "${out%% plan=*}" = "status=blocked task=2 waiting=1" ]; then pass "a mention of completion inside another line does not satisfy a dependency"; else fail "mention blocks (rc=$rc: $out)"; fi
printf -- '- Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$MP_WS/progress.md"
out=$(run_state "$TEST_ROOT/ev4" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=2 branch=none" ]; then pass "a list-marked completion line satisfies the dependency"; else fail "marked completion (rc=$rc: $out)"; fi


echo "next: the claimable frontier"
make_pair nx; nx_a=$PAIR_A
mkdir -p "$nx_a/docs"; : > "$nx_a/docs/spec.md"
cat > "$nx_a/docs/plan.md" <<'PLAN'
# P

**Spec:** docs/spec.md

### Task 1: A

**Risk tier:** standard

**Depends on:** none

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

### Task 3: C

**Risk tier:** standard

**Depends on:** none

### Task 4: D

**Risk tier:** standard

**Depends on:** Task 3

### Task 5: E

**Risk tier:** standard

**Depends on:** Task 2, Task 4
PLAN
git -C "$nx_a" add docs; git -C "$nx_a" commit -qm plan; git -C "$nx_a" push -q origin main 2>/dev/null; git -C "$nx_a" switch -q -c feat
run_state "$nx_a" sync docs/plan.md >/dev/null 2>&1; wsnx=$(run_sdd_dir "$nx_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsnx/progress.md"
run_state "$nx_a" register docs/plan.md --session s1 --integration feat >/dev/null
make_repo "$TEST_ROOT/foreign-nx"
out=$(run_state "$nx_a" next docs/plan.md --session s1 --code-repo "$TEST_ROOT/foreign-nx" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "next refuses a foreign --code-repo"; else fail "next wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign-nx" && bash "$SDD_STATE" next "$nx_a/docs/plan.md" --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "next run from a foreign repository without --code-repo is wrong-repo"; else fail "next foreign cwd (rc=$rc: $out)"; fi
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1,3 own-blocked=none" ]; then pass "the frontier is the tasks with no incomplete predecessor, in plan order"; else fail "frontier (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 1 --session s1 >/dev/null; run_state "$nx_a" claim docs/plan.md 3 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1 own-blocked=none" ]; then pass "this session's own claim is listed first and a held task is not listed"; else fail "own first (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=2 own-blocked=none" ]; then pass "a completed predecessor opens its dependent"; else fail "dependent opens (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 2 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=held held=2@s2,3@s2 waiting=4,5" ]; then pass "every open task held or waiting on a held one reads held with holders"; else fail "none held (rc=$rc: $out)"; fi
printf 'session s1: tasks 5\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=blocked waiting=5 excluded=2,3,4 held=2@s2,3@s2" ]; then pass "an assigned list narrows the frontier: a predecessor outside the list is an exclusion, and the holders are still named"; else fail "assigned blocked (rc=$rc: $out)"; fi
sed -i '' '/^session s1: tasks 5$/d' "$wsnx/progress.md" 2>/dev/null || sed -i '/^session s1: tasks 5$/d' "$wsnx/progress.md"
printf 'session s1: tasks 4\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=blocked waiting=4 excluded=2,3,5 held=2@s2,3@s2" ]; then pass "an allowed task whose held predecessor is outside the list waits on the exclusion"; else fail "allowed waiting-on-excluded (rc=$rc: $out)"; fi
printf 'Task 3: complete (commits 3333333..4444444, review clean)\nTask 2: complete (commits 5555555..6666666, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=4 own-blocked=none" ]; then pass "the assigned task becomes claimable when its predecessor completes"; else fail "assigned claimable (rc=$rc: $out)"; fi
printf 'Task 4: complete (commits 7777777..8888888, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=assigned-complete remaining=5" ]; then pass "a finished assigned list reports the remaining tasks"; else fail "assigned-complete (rc=$rc: $out)"; fi
sed -i '' '/^session s1: tasks 4$/d' "$wsnx/progress.md" 2>/dev/null || sed -i '/^session s1: tasks 4$/d' "$wsnx/progress.md"
printf 'session s2: tasks 1,2,3\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=assigned-complete remaining=5" ]; then pass "an excluded open task with complete predecessors is still excluded"; else fail "excluded (rc=$rc: $out)"; fi
# own-blocked: an edge amended onto a claimed task; Task 7 behind it is a descendant of an own-blocked task and is neither offered nor named.
run_state "$nx_a" claim docs/plan.md 5 --session s1 >/dev/null
sed -i '' 's/^\*\*Depends on:\*\* Task 2, Task 4$/**Depends on:** Task 2, Task 4, Task 6/' "$nx_a/docs/plan.md" 2>/dev/null || sed -i 's/^\*\*Depends on:\*\* Task 2, Task 4$/**Depends on:** Task 2, Task 4, Task 6/' "$nx_a/docs/plan.md"
printf '\n### Task 6: F\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 7: G\n\n**Risk tier:** standard\n\n**Depends on:** Task 5\n' >> "$nx_a/docs/plan.md"
git -C "$nx_a" add docs; git -C "$nx_a" commit -qm amend
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=6 own-blocked=5" ]; then pass "a claimable task is offered, the own-blocked task is named, and its descendant is neither"; else fail "own-blocked with frontier (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 6 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=own-blocked task=5 waiting=6@s2" ]; then pass "an own claim whose new predecessor is held reads own-blocked"; else fail "own-blocked (rc=$rc: $out)"; fi
printf 'Task 6: complete (commits 9999999..aaaaaaa, review clean)\nTask 5: complete (commits bbbbbbb..ccccccc, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=7 own-blocked=none" ]; then pass "the descendant opens once the own-blocked task completes"; else fail "descendant opens (rc=$rc: $out)"; fi
printf 'Task 7: complete (commits ddddddd..eeeeeee, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=complete" ]; then pass "every task complete reads complete"; else fail "complete (rc=$rc: $out)"; fi
# A plan line whose ref does not carry the plan file is an error, never a read of the worktree copy.
printf '# U\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$nx_a/docs/unc.md"
wsunc=$(run_sdd_dir "$nx_a" docs/unc.md 2>/dev/null); printf '# SDD ledger — plan: docs/unc.md\n' > "$wsunc/progress.md"
run_state "$nx_a" register docs/unc.md --session s9 --integration feat >/dev/null
err=$(run_state "$nx_a" next docs/unc.md --session s9 2>&1 >"$TEST_ROOT/nx.unc"); rc=$?
if [ "$rc" -eq 2 ] && [ "$(cat "$TEST_ROOT/nx.unc")" = "status=error" ] && printf '%s' "$err" | grep -q 'does not carry docs/unc.md'; then pass "a registered plan its ref does not carry is an error, not a worktree read"; else fail "uncommitted registered plan (rc=$rc: $(cat "$TEST_ROOT/nx.unc"): $err)"; fi
rm -f "$nx_a/docs/unc.md"; rm -rf "$wsunc"
# A heading that carries shell text is a parse error, and nothing runs it.
nx_mark="$TEST_ROOT/nx.pwned"
mkplan nxi "$(printf '# P\n\n### Task 1: A\n\n### Task 2:x$(touch %s)\n' "$nx_mark")"
err=$(run_state "$TEST_ROOT/nxi" next docs/plan.md --session s1 2>&1 >"$TEST_ROOT/nx.inj"); rc=$?
if [ "$rc" -eq 2 ] && [ "$(sed 's/ plan=.*//' "$TEST_ROOT/nx.inj")" = "status=invalid" ] && [ ! -e "$nx_mark" ] && printf '%s' "$err" | grep -q 'malformed task heading'; then pass "a task heading carrying shell text is invalid and runs nothing"; else fail "heading injection (rc=$rc: $(cat "$TEST_ROOT/nx.inj"): $err; marker=$([ -e "$nx_mark" ] && echo made || echo none))"; fi
# Own claims lead in heading order, then the rest in heading order.
mkplan nxo $'# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** none\n\n### Task 3: C\n\n**Depends on:** none\n'
nxo_ws=$MP_WS
run_state "$TEST_ROOT/nxo" claim docs/plan.md 1 --session s1 >/dev/null; run_state "$TEST_ROOT/nxo" claim docs/plan.md 3 --session s1 >/dev/null
out=$(run_state "$TEST_ROOT/nxo" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1,3,2 own-blocked=none" ]; then pass "own claims lead in heading order, then the unclaimed tasks"; else fail "own claims order (rc=$rc: $out)"; fi
# A session id is matched as text: s.1 does not read sx1's assignment.
printf 'session sx1: tasks 1\n' >> "$nxo_ws/progress.md"
out=$(run_state "$TEST_ROOT/nxo" next docs/plan.md --session s.1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=2 own-blocked=none" ]; then pass "a session id with a regex metacharacter does not pick up another session's assignment"; else fail "sid metacharacter (rc=$rc: $out)"; fi
# A plan with no task headings has nothing to claim.
mkplan nxe $'# P\n'
out=$(run_state "$TEST_ROOT/nxe" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=complete" ]; then pass "a plan with no task headings reads complete"; else fail "empty graph (rc=$rc: $out)"; fi
# Held outranks excluded among an allowed task's predecessors.
mkplan nxp $'# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** none\n\n### Task 3: C\n\n**Depends on:** Task 1, Task 2\n'
nxp_ws=$MP_WS
run_state "$TEST_ROOT/nxp" claim docs/plan.md 2 --session s2 >/dev/null
printf 'session s1: tasks 2,3\n' >> "$nxp_ws/progress.md"
out=$(run_state "$TEST_ROOT/nxp" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=held held=2@s2 waiting=3" ]; then pass "a task waiting on both a held and an excluded predecessor reads held"; else fail "held over excluded (rc=$rc: $out)"; fi
# An unreadable ledger is an error, never "not complete".
chmod a-r "$nxp_ws/progress.md"
out=$(run_state "$TEST_ROOT/nxp" next docs/plan.md --session s1 2>/dev/null); rc=$?
chmod u+r "$nxp_ws/progress.md"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "an unreadable ledger is status=error"; else fail "unreadable ledger (rc=$rc: $out)"; fi
# next recovers an interrupted sync under the lock before it classifies: a stale ledger must not offer a task the newer assignment line excludes.
make_pair nr; nr_a=$PAIR_A; nr_b=$PAIR_B
mkdir -p "$nr_a/docs"; : > "$nr_a/docs/spec.md"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 2: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$nr_a/docs/plan.md"
git -C "$nr_a" add docs; git -C "$nr_a" commit -qm plan; git -C "$nr_a" push -q origin main 2>/dev/null
run_state "$nr_a" sync docs/plan.md >/dev/null 2>&1; git -C "$nr_a" push -q origin hyperpowers/state 2>/dev/null; git -C "$nr_b" pull -q origin main 2>/dev/null; run_state "$nr_b" sync docs/plan.md >/dev/null 2>&1
wsnr=$(run_sdd_dir "$nr_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsnr/progress.md"
run_state "$nr_a" register docs/plan.md --session s1 --integration main >/dev/null 2>&1
run_state "$nr_a" snapshot docs/plan.md >/dev/null 2>&1; git -C "$nr_a" push -q origin hyperpowers/state 2>/dev/null
run_state "$nr_b" sync docs/plan.md >/dev/null 2>&1
printf 'session s1: tasks 2\n' >> "$wsnr/progress.md"
run_state "$nr_a" snapshot docs/plan.md >/dev/null 2>&1; git -C "$nr_a" push -q origin hyperpowers/state 2>/dev/null
( cd "$nr_b" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
out=$(run_state "$nr_b" next docs/plan.md --session s1 2>/dev/null); rcn=$?
if [ "$rc" -eq 99 ] && [ "$rcn" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=2 own-blocked=none" ]; then pass "next recovers an interrupted sync and offers only what the recovered assignment allows"; else fail "next after crashed sync (rc=$rc/$rcn: $out)"; fi
# A crashed sync that was introducing the workspace leaves no ledger yet; next still recovers it and reports the frontier.
make_pair nw; nw_a=$PAIR_A; nw_b=$PAIR_B
mkdir -p "$nw_a/docs"; : > "$nw_a/docs/spec.md"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$nw_a/docs/plan.md"
git -C "$nw_a" add docs; git -C "$nw_a" commit -qm plan; git -C "$nw_a" push -q origin main 2>/dev/null
run_state "$nw_a" sync docs/plan.md >/dev/null 2>&1; git -C "$nw_a" push -q origin hyperpowers/state 2>/dev/null; git -C "$nw_b" pull -q origin main 2>/dev/null; run_state "$nw_b" sync docs/plan.md >/dev/null 2>&1
wsnw=$(run_sdd_dir "$nw_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsnw/progress.md"
run_state "$nw_a" register docs/plan.md --session s1 --integration main >/dev/null 2>&1
run_state "$nw_a" snapshot docs/plan.md >/dev/null 2>&1; git -C "$nw_a" push -q origin hyperpowers/state 2>/dev/null
( cd "$nw_b" && HYPERPOWERS_TEST_CRASH_AT=sync-after-update-ref bash "$SDD_STATE" sync docs/plan.md >/dev/null 2>&1 ); rc=$?
wsnw_b=$(run_sdd_dir "$nw_b" docs/plan.md 2>/dev/null)
nw_absent=0; [ ! -e "$wsnw_b/progress.md" ] && nw_absent=1
out=$(run_state "$nw_b" next docs/plan.md --session s1 2>/dev/null); rcn=$?
if [ "$rc" -eq 99 ] && [ "$nw_absent" -eq 1 ] && [ "$rcn" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1 own-blocked=none" ] && [ ! -e "$(dirname "$(dirname "$wsnw_b")")/.sync-applying" ]; then pass "next recovers a crashed sync that was introducing the workspace and reports the frontier"; else fail "next after crashed first sync (rc=$rc/$rcn absent=$nw_absent: $out)"; fi
# A claim directory whose owner is unreadable or has no session is an error, not an unclaimed task.
mkplan nxk $'# P\n\n### Task 1: A\n\n**Depends on:** none\n'
nxk_ws=$MP_WS
mkdir -p "$nxk_ws/claims/task-1"; printf 'session=s2\n' > "$nxk_ws/claims/task-1/owner"; chmod 000 "$nxk_ws/claims/task-1/owner"
out=$(run_state "$TEST_ROOT/nxk" next docs/plan.md --session s1 2>/dev/null); rc=$?
chmod 600 "$nxk_ws/claims/task-1/owner"
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "a claim whose owner file is unreadable is status=error"; else fail "unreadable owner (rc=$rc: $out)"; fi
printf 'host=h\n' > "$nxk_ws/claims/task-1/owner"
out=$(run_state "$TEST_ROOT/nxk" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "a claim whose owner file has no session is status=error"; else fail "ownerless claim (rc=$rc: $out)"; fi
# The code-repository errors still print one status line.
mkdir -p "$TEST_ROOT/nogit"
out=$(cd "$TEST_ROOT/nogit" && bash "$SDD_STATE" next "$nx_a/docs/plan.md" --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "next outside any repository prints status=error"; else fail "nogit cwd (rc=$rc: $out)"; fi
out=$(run_state "$nx_a" next docs/plan.md --session s1 --code-repo "$TEST_ROOT/does-not-exist" 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "next with a missing --code-repo prints status=error"; else fail "missing code repo (rc=$rc: $out)"; fi

if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi
echo "STATUS: PASSED"
