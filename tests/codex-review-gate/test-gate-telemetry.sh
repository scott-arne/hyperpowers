#!/usr/bin/env bash
# shellcheck disable=SC2015,SC1010
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GT="$REPO_ROOT/skills/requesting-code-review/scripts/gate-telemetry"
UL="$REPO_ROOT/skills/requesting-code-review/scripts/ungated-ledger"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
expect() { printf '%s' "$1" | grep -Fq "$2" && pass "$3" || fail "$3 (missing: $2)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/gt-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME="$work/cache"

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
b="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
h="$(git -C "$repo" rev-parse HEAD)"
key="$(printf '%s' "$(git -C "$repo" rev-parse --absolute-git-dir)" | git -C "$repo" hash-object --stdin)"

# Synthetic scratch: 3 SDD tasks, 1 with a fix brief; 2 parseable gate runs
# (task at 2/3, final at 4/3 = backstopped), 1 unparseable gate-round.json,
# 1 old-format run dir with NO gate-round.json at all.
sdd="$XDG_CACHE_HOME/hyperpowers/sdd/$key"; mkdir -p "$sdd"
for n in 1 2 3; do echo brief > "$sdd/task-$n-brief.md"; echo report > "$sdd/task-$n-report.md"; done
echo fix > "$sdd/task-2-codex-fix-brief.md"
cr="$XDG_CACHE_HOME/hyperpowers/codex-review/$key"
mkdir -p "$cr/run-aaa" "$cr/run-bbb" "$cr/run-old" "$cr/run-noformat"
printf '{"round":2,"ceiling":3,"gate":"task"}\n' > "$cr/run-aaa/gate-round.json"
printf '{"round":4,"ceiling":3,"gate":"final"}\n' > "$cr/run-bbb/gate-round.json"
printf 'not json\n' > "$cr/run-old/gate-round.json"
touch "$cr/run-noformat/spec-review-prompt.md"

# Ledger: one pending, one swept, one doc (unsweepable-class) event
bash "$UL" append --class degraded-gate --gate task --base "$b" --head "$h" --status stale-broker --note x "$repo" >/dev/null
out="$(bash "$UL" append --class incomplete-review --gate task --base "$b" --head "$h" --status incomplete --note y "$repo")"
id2="$(printf '%s' "$out" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).id)')"
bash "$UL" mark-swept --ref "$id2" --verdict approved --note done "$repo" >/dev/null
bash "$UL" append --class degraded-gate --gate spec --status not-ready --note z "$repo" >/dev/null

echo "gate-telemetry:"

md="$( (cd "$repo" && bash "$GT") )"
expect "$md" 'stale-broker: 1' "degrades bucketed by token"
expect "$md" 'not-ready: 1' "doc degrade counted"
expect "$md" 'Backstop rate' "backstop metric present"
expect "$md" '1/2' "backstop rate 1 of 2 parseable runs"
expect "$md" 'final: [4] (backstops 1/1)' "rounds and backstops bucketed by gate type"
expect "$md" 'task: [2] (backstops 0/1)' "non-backstopped type bucketed too"
expect "$md" 'old-format runs: 1' "run dirs without round data reported"
expect "$md" 'Fix-cycle rate' "fix-cycle metric present"
expect "$md" '1/3' "fix rate 1 of 3 tasks"
expect "$md" 'Pending: 1' "pending backlog"
expect "$md" 'Oldest pending: 0 day(s)' "oldest pending age computed"
expect "$md" 'Swept: 1' "sweep outcomes counted"
expect "$md" 'skipped: 1' "unparseable artifact reported"

js="$( (cd "$repo" && bash "$GT" --json) )"
printf '%s' "$js" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));const r=d.repos[0];if(r.pending!==1||r.backstops!==1||r.skipped<1||r.oldFormatRuns!==1||r.byGate.final.backstops!==1||r.byGate.task.runs!==1||r.oldestPendingDays!==0)process.exit(1)' \
  && pass "--json parses with matching numbers incl. byGate/age/old-format" || fail "--json parses with matching numbers incl. byGate/age/old-format"

# Second fixture key so --all has something to aggregate across.
key2="deadbeef2222222222222222222222222222dead"
mkdir -p "$XDG_CACHE_HOME/hyperpowers/codex-review/$key2/run-ccc"
printf '{"round":1,"ceiling":4,"gate":"spec"}\n' > "$XDG_CACHE_HOME/hyperpowers/codex-review/$key2/run-ccc/gate-round.json"

# Degrade metric purity: the class-3 event carries status "incomplete" but
# must NOT appear under Degrades (preflight tokens only).
printf '%s' "$md" | grep -q 'incomplete: 1' && fail "class-3 status stays out of Degrades" || pass "class-3 status stays out of Degrades"

alljs="$(bash "$GT" --json --all)"
printf '%s' "$alljs" | grep -Fq "$key" && pass "--all covers the fixture key" || fail "--all covers the fixture key"
printf '%s' "$alljs" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));const a=d.aggregate;if(d.repos.length!==2||a.runs!==3||a.backstops!==1||a.pending!==1||a.oldestPendingDays!==0||a.swept.approved!==1||a.byGate.spec.runs!==1||a.byGate.final.backstops!==1)process.exit(1)' \
  && pass "--all aggregate sums incl. byGate/age/swept-by-verdict" || fail "--all aggregate sums incl. byGate/age/swept-by-verdict"
allmd="$(bash "$GT" --all)"
printf '%s' "$allmd" | grep -Fq 'Fleet aggregate (2 repos)' && pass "--all markdown has fleet section" || fail "--all markdown has fleet section"
printf '%s' "$allmd" | grep -Fq 'Backstop rate: 1/3' && pass "fleet backstop rate combined" || fail "fleet backstop rate combined"
printf '%s' "$allmd" | grep -Fq 'spec: [1] (backstops 0/1)' && pass "fleet rounds-by-gate present" || fail "fleet rounds-by-gate present"
printf '%s' "$allmd" | grep -Fq 'Oldest pending: 0 day(s)' && pass "fleet oldest-pending present" || fail "fleet oldest-pending present"
printf '%s' "$allmd" | grep -Fq '(approved:1)' && pass "fleet swept-by-verdict present" || fail "fleet swept-by-verdict present"

bash "$GT" "$work" >/dev/null 2>&1 && fail "non-repo without --all exits 2" || pass "non-repo without --all exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
