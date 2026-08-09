#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RD="$REPO_ROOT/skills/requesting-code-review/scripts/review-dossier"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
dossier_has() { grep -Fq "$2" "$1" && pass "$3" || fail "$3 (missing: $2)"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/rd-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

repo="$work/repo"; mkdir -p "$repo"; git -C "$repo" init -q
printf 'line one\n' > "$repo/a.txt"
git -C "$repo" add a.txt; git -C "$repo" -c user.email=t@t -c user.name=t commit -qm one
b="$(git -C "$repo" rev-parse HEAD)"
printf 'line two\n' >> "$repo/a.txt"
git -C "$repo" add a.txt; git -C "$repo" -c user.email=t@t -c user.name=t commit -qm two
h="$(git -C "$repo" rev-parse HEAD)"

gd="$work/gate"; mkdir -p "$gd"
specdoc="$work/spec.md"; printf '# Spec\nreq one\n' > "$specdoc"
adj="$work/adj.md"; printf 'Declined: X because Y\n' > "$adj"
ev="$work/report.md"; printf 'GREEN: 12/12 pass\n' > "$ev"

echo "review-dossier:"

# spec gate: documents + adjudications expected; test evidence NOT APPLICABLE
out="$(bash "$RD" --gate spec --out "$gd" --spec "$specdoc" --adjudications "$adj" "$repo")"
printf '%s' "$out" | grep -Fq '"ok":true' && pass "spec dossier ok" || fail "spec dossier ok (got $out)"
printf '%s' "$out" | grep -Fq '"sections":5' && pass "always five sections" || fail "always five sections"
printf '%s' "$out" | grep -Fq '"missing":0' && pass "no missing when expected supplied" || fail "no missing (got $out)"
d="$gd/dossier.md"
for hdr in '## Documents under review' '## Adjudicated decisions' '## Test evidence' '## Changed surfaces' '## Review package'; do
  dossier_has "$d" "$hdr" "section present: $hdr"
done
grep -Fq "$(printf '\t2\treq one')" "$d" && pass "documents are line-numbered (tab-N-tab format)" || fail "documents are line-numbered"
dossier_has "$d" 'req one' "spec content inlined"
dossier_has "$d" 'Declined: X because Y' "adjudications inlined"
grep -Fq 'NOT APPLICABLE' "$d" && pass "test evidence NOT APPLICABLE for spec gate" || fail "test evidence NOT APPLICABLE for spec gate"
grep -Eq 'NOT APPLICABLE.*test evidence|Test evidence' "$d" >/dev/null 2>&1 || true

# task gate: adjudications + evidence + range expected; documents NOT APPLICABLE;
# omit evidence -> NOT PROVIDED counted in missing
gd2="$work/gate2"; mkdir -p "$gd2"
out="$(bash "$RD" --gate task --out "$gd2" --adjudications "$adj" --base "$b" --head "$h" "$repo")"
printf '%s' "$out" | grep -Fq '"missing":1' && pass "missing expected input counted" || fail "missing counted (got $out)"
d2="$gd2/dossier.md"
dossier_has "$d2" 'NOT PROVIDED' "expected-but-absent renders NOT PROVIDED"
dossier_has "$d2" 'NOT APPLICABLE' "unexpected input renders NOT APPLICABLE"
dossier_has "$d2" 'a.txt' "changed surfaces lists the file"

# unreadable expected input -> NOT PROVIDED with reason
gd3="$work/gate3"; mkdir -p "$gd3"
out="$(bash "$RD" --gate task --out "$gd3" --adjudications "$work/nope.md" --test-evidence "$ev" --base "$b" --head "$h" "$repo")"
d3="$gd3/dossier.md"
dossier_has "$d3" 'file unreadable' "unreadable file names the reason"

# truncation: a 4005-line doc gets the exact marker
big="$work/big.md"; seq 1 4005 > "$big"
gd4="$work/gate4"; mkdir -p "$gd4"
bash "$RD" --gate spec --out "$gd4" --spec "$big" --adjudications "$adj" "$repo" >/dev/null
dossier_has "$gd4/dossier.md" 'TRUNCATED at line 4000 of 4005' "explicit truncation marker"
grep -Fq $'\t4001\t' "$gd4/dossier.md" && fail "no lines beyond the cap" || pass "no lines beyond the cap"

# expected range that git cannot compute -> NOT PROVIDED, missing counted
gd5="$work/gate5"; mkdir -p "$gd5"
out="$(bash "$RD" --gate task --out "$gd5" --adjudications "$adj" --test-evidence "$ev" --base deadbeef --head "$h" "$repo")"
printf '%s' "$out" | grep -Fq '"missing":1' && pass "failed git range counted as missing" || fail "failed git range counted as missing (got $out)"
grep -Fq 'NOT PROVIDED: GIT ERROR' "$gd5/dossier.md" && pass "failed range renders NOT PROVIDED" || fail "failed range renders NOT PROVIDED"

# valid range with zero changes -> content, not missing
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m e1
e1="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m e2
e2="$(git -C "$repo" rev-parse HEAD)"
gd6="$work/gate6"; mkdir -p "$gd6"
out="$(bash "$RD" --gate task --out "$gd6" --adjudications "$adj" --test-evidence "$ev" --base "$e1" --head "$e2" "$repo")"
printf '%s' "$out" | grep -Fq '"missing":0' && pass "empty valid range is not missing" || fail "empty valid range is not missing (got $out)"
grep -Fq 'no textual changes in' "$gd6/dossier.md" && pass "empty range renders as determinate content" || fail "empty range renders as determinate content"

# usage errors -> exit 2
bash "$RD" --gate bogus --out "$gd" "$repo" >/dev/null 2>&1 && fail "bad gate exits 2" || pass "bad gate exits 2"
bash "$RD" --gate spec "$repo" >/dev/null 2>&1 && fail "missing --out exits 2" || pass "missing --out exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
