#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VN="$REPO_ROOT/skills/requesting-code-review/scripts/verdict-normalize"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
check() { # <file> <fragment> <desc>
  local out; out="$(bash "$VN" "$1")"
  printf '%s' "$out" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $out)"
}

work="$(mktemp -d "${TMPDIR:-/tmp}/vn-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

echo "verdict-normalize:"

# --- document-gate text shapes ---
cat > "$work/approve.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Non-blocking Findings:
- severity: medium
  title: nit

Summary: fine.
EOF
check "$work/approve.txt" '"result":"approved"' "text approve -> approved"

cat > "$work/needs.txt" <<'EOF'
Verdict: needs-attention

Blocking Findings:
- severity: high
  title: broken thing
- severity: critical
  title: worse thing

Non-blocking Findings:
None

Summary: fix.
EOF
check "$work/needs.txt" '"result":"blocking"' "text needs-attention -> blocking"
check "$work/needs.txt" '"blockingCount":2' "counts blocking findings"

cat > "$work/cutoff.txt" <<'EOF'
I'm formatting the verdict exactly as requested
EOF
check "$work/cutoff.txt" '"result":"incomplete"' "cut-off text -> incomplete"

# contradiction: approve but blocking findings listed -> blocking (conservative)
cat > "$work/contra.txt" <<'EOF'
Verdict: approve

Blocking Findings:
- severity: high
  title: sneaky

Summary: hm.
EOF
check "$work/contra.txt" '"result":"blocking"' "approve+blocking findings -> blocking"

# --- code-gate JSON payloads ---
cat > "$work/approve.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [] },
  "rawOutput": "Verdict: approve" } } }
EOF
check "$work/approve.json" '"result":"approved"' "json approve -> approved"

cat > "$work/blocking.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "needs-attention",
    "findings": [ { "severity": "high", "title": "bug" },
                  { "severity": "low", "title": "nit" } ] },
  "rawOutput": "..." } } }
EOF
check "$work/blocking.json" '"result":"blocking"' "json needs-attention -> blocking"
check "$work/blocking.json" '"blockingCount":1' "json counts only critical/high"

cat > "$work/novderdict.json" <<'EOF'
{ "storedJob": { "result": { "parseError": "schema mismatch",
  "result": null, "rawOutput": "still verifying the diff" } } }
EOF
check "$work/novderdict.json" '"result":"incomplete"' "null result payload -> incomplete"

# empty file -> incomplete
: > "$work/empty.txt"
check "$work/empty.txt" '"result":"incomplete"' "empty file -> incomplete"

# missing file -> internal error (exit 2)
bash "$VN" "$work/nope.txt" >/dev/null 2>&1 && fail "missing file exits non-zero" || pass "missing file exits non-zero"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
