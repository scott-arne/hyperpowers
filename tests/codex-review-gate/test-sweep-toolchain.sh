#!/usr/bin/env bash
# Exercises §7's mechanical sequence exactly as the doc prescribes it:
# valid range -> review checkout -> (stub verdict) -> mark-swept approved;
# invalid base -> unsweepable; head != current HEAD -> detached worktree,
# validation inside it, closure under the SOURCE key from worktree cwd.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
S="$REPO_ROOT/skills/requesting-code-review/scripts"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

work="$(mktemp -d "${TMPDIR:-/tmp}/sw-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m three  # HEAD moves past h
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"

echo "sweep toolchain:"

# Three pending events: valid range (head != current HEAD), invalid base, valid-at-HEAD.
id_wt="$(bash "$S/ungated-ledger" append --class degraded-gate --gate task --base "$b" --head "$h" --status not-ready --note wt "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
id_bad="$(bash "$S/ungated-ledger" append --class degraded-gate --gate task --base deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head "$h" --status not-ready --note bad "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
cur="$(git -C "$repo" rev-parse HEAD)"
id_ok="$(bash "$S/ungated-ledger" append --class incomplete-review --gate final --base "$b" --head "$cur" --status incomplete --note ok "$repo" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"

SWEEP_REPO="$repo"

# Path A (invalid base): head resolves, base-ref-ok fails -> unsweepable.
git -C "$SWEEP_REPO" rev-parse --verify "$h^{commit}" >/dev/null 2>&1 || fail "precondition: head resolves"
out="$(bash "$S/base-ref-ok" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"ok":false' && pass "invalid base rejected by base-ref-ok" || fail "invalid base rejected"
bash "$S/ungated-ledger" mark-swept --ref "$id_bad" --verdict unsweepable --note "base unresolvable" "$SWEEP_REPO" >/dev/null

# Path B (valid at current HEAD): fast path, stub verdict -> approved.
out="$(bash "$S/base-ref-ok" "$b" "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"ok":true' && pass "fast-path base validates in place" || fail "fast-path base validates"
cat > "$work/stub-verdict.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Non-blocking Findings:
None

Cannot verify:
None

Summary: sweep stub.
EOF
out="$(bash "$S/verdict-normalize" "$work/stub-verdict.txt")"
printf '%s' "$out" | grep -Fq '"result":"approved"' && pass "stub verdict normalizes approved" || fail "stub verdict normalizes"
bash "$S/ungated-ledger" mark-swept --ref "$id_ok" --verdict approved --note "sweep clean" "$SWEEP_REPO" >/dev/null

# Path C (head behind HEAD): detached worktree, validate inside, close from
# worktree cwd with explicit SWEEP_REPO.
wt="$work/wt"; git -C "$SWEEP_REPO" worktree add --detach "$wt" "$h" >/dev/null 2>&1
out="$(bash "$S/base-ref-ok" "$b" "$wt")"
printf '%s' "$out" | grep -Fq '"ok":true' && pass "base validates against recorded head in worktree" || fail "base validates in worktree (got $out)"
( cd "$wt" && bash "$S/ungated-ledger" mark-swept --ref "$id_wt" --verdict approved --note "swept via worktree" "$SWEEP_REPO" >/dev/null )
git -C "$SWEEP_REPO" worktree remove --force "$wt" >/dev/null 2>&1; git -C "$SWEEP_REPO" worktree prune >/dev/null 2>&1
[ ! -d "$wt" ] && pass "worktree cleaned up" || fail "worktree cleaned up"

# All three closed under the SOURCE key; nothing under any other key.
out="$(bash "$S/ungated-ledger" pending --count "$SWEEP_REPO")"
printf '%s' "$out" | grep -Fq '"count":0' && pass "all pending closed under source key" || fail "all pending closed (got $out)"
[ "$(ls "$XDG_CACHE_HOME/hyperpowers/ungated")" = "$key" ] && pass "the only ledger key is the source repo's" || fail "the only ledger key is the source repo's (found: $(ls "$XDG_CACHE_HOME/hyperpowers/ungated" | tr '\n' ' '))"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
