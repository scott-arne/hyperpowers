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

# verdict text quoted inside a finding body must not shadow the terminal verdict
cat > "$work/quoted.txt" <<'EOF'
Blocking Findings:
- severity: critical
  title: wrong verdict emitted
  issue: current output is:
Verdict: approve
  recommendation: emit needs-attention instead

Verdict: needs-attention

Summary: fix.
EOF
check "$work/quoted.txt" '"verdict":"needs-attention"' "quoted verdict in finding does not shadow terminal verdict"
check "$work/quoted.txt" '"result":"blocking"' "quoted-verdict case still blocking"

# mirror case: needs-attention at top, quoted approve later -> still needs-attention
cat > "$work/mirror.txt" <<'EOF'
Verdict: needs-attention

Blocking Findings:
None

Cannot verify:
The spec says:
Verdict: approve
but current output does not match.

Summary: verify.
EOF
check "$work/mirror.txt" '"verdict":"needs-attention"' "needs-attention precedence over later quoted approve"
check "$work/mirror.txt" '"result":"blocking"' "needs-attention with zero blocking -> blocking"

# empty file -> incomplete
: > "$work/empty.txt"
check "$work/empty.txt" '"result":"incomplete"' "empty file -> incomplete"

# structural completeness: approve requires Blocking Findings section + Summary
cat > "$work/verdict-only.txt" <<'EOF'
Verdict: approve
EOF
check "$work/verdict-only.txt" '"result":"incomplete"' "approve without structure -> incomplete"

cat > "$work/no-summary.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None
EOF
check "$work/no-summary.txt" '"result":"incomplete"' "approve without Summary -> incomplete"

cat > "$work/no-blocking-section.txt" <<'EOF'
Verdict: approve

Summary: looks good.
EOF
check "$work/no-blocking-section.txt" '"result":"incomplete"' "approve without Blocking Findings section -> incomplete"

# structural completeness: Summary header must have content
cat > "$work/empty-summary.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Summary:
EOF
check "$work/empty-summary.txt" '"result":"incomplete"' "approve with empty Summary header -> incomplete"

# --- coverage floor (--require-coverage) ---
checkc() { # with --require-coverage: <file> <fragment> <desc>
  local out; out="$(bash "$VN" --require-coverage "$1")"
  printf '%s' "$out" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $out)"
}

cat > "$work/cov-ok.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Coverage:
- documents read: spec.md in full
- adjudications considered: 2 declined items
- changed surfaces reviewed: not applicable: document gate
- test evidence inspected: not applicable: document gate

Summary: fine.
EOF
checkc "$work/cov-ok.txt" '"result":"approved"' "flag: approve WITH coverage stays approved"

cat > "$work/cov-missing.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Summary: fine.
EOF
checkc "$work/cov-missing.txt" '"result":"incomplete"' "flag: approve without Coverage -> incomplete"
checkc "$work/cov-missing.txt" 'approve without coverage evidence' "flag: reason names the floor"
check  "$work/cov-missing.txt" '"result":"approved"' "no flag: byte-identical (still approved)"

cat > "$work/cov-bare.txt" <<'EOF'
Verdict: approve

Blocking Findings:
None

Coverage:

Summary: fine.
EOF
checkc "$work/cov-bare.txt" '"result":"incomplete"' "flag: bare Coverage heading -> incomplete"

# needs-attention unaffected by the flag
checkc "$work/needs.txt" '"result":"blocking"' "flag: needs-attention unaffected"

# JSON path: structured approve honored ONLY with coverage in raw text
cat > "$work/cov-json-ok.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [] },
  "rawOutput": "Verdict: approve\n\nCoverage:\n- changed surfaces reviewed: all 3 files\n\nSummary: ok" } } }
EOF
checkc "$work/cov-json-ok.json" '"result":"approved"' "flag: JSON approve with coverage in rawOutput -> approved"

cat > "$work/cov-json-none.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [] },
  "rawOutput": "Verdict: approve\n\nSummary: ok" } } }
EOF
checkc "$work/cov-json-none.json" '"result":"incomplete"' "flag: JSON approve without coverage -> incomplete"
check  "$work/cov-json-none.json" '"result":"approved"' "no flag: JSON path byte-identical"

# JSON blocking unaffected by the flag
checkc "$work/blocking.json" '"result":"blocking"' "flag: JSON needs-attention unaffected"

# structured approve with coverage in summary field
cat > "$work/cov-structured-ok.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [],
    "summary": "Coverage: documents read — dossier; changed surfaces — full diff. Ship: I cannot support a material blocker from the supplied diff." },
  "rawOutput": "{\"verdict\":\"approve\",\"summary\":\"Coverage: documents read — dossier; changed surfaces — full diff. Ship: I cannot support a material blocker from the supplied diff.\",\"findings\":[],\"next_steps\":[]}" } } }
EOF
checkc "$work/cov-structured-ok.json" '"result":"approved"' "flag: structured approve with Coverage in summary -> approved"

# structured approve without coverage in summary
cat > "$work/cov-structured-none.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [],
    "summary": "Ship: I cannot support a material blocker from the supplied diff." },
  "rawOutput": "{\"verdict\":\"approve\",\"summary\":\"Ship: I cannot support a material blocker from the supplied diff.\",\"findings\":[],\"next_steps\":[]}" } } }
EOF
checkc "$work/cov-structured-none.json" '"result":"incomplete"' "flag: structured approve without Coverage in summary -> incomplete"
checkc "$work/cov-structured-none.json" 'approve without coverage evidence' "flag: structured none reason names the floor"
check  "$work/cov-structured-none.json" '"result":"approved"' "no flag: structured path byte-identical (still approved)"

# structured needs-attention with Coverage quoted in finding body (must NOT satisfy floor)
cat > "$work/cov-finding-body.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "needs-attention", "findings": [
    { "severity": "high", "title": "missing coverage", "issue": "Coverage: yes is not in the output" }
  ], "summary": "Fix the missing coverage section." },
  "rawOutput": "{\"verdict\":\"needs-attention\",\"summary\":\"Fix the missing coverage section.\",\"findings\":[{\"severity\":\"high\",\"title\":\"missing coverage\",\"issue\":\"Coverage: yes is not in the output\"}]}" } } }
EOF
checkc "$work/cov-finding-body.json" '"result":"blocking"' "flag: needs-attention with Coverage in finding body stays blocking"

# same fixture as above but with verdict:approve - floor must NOT be satisfied by finding body
cat > "$work/cov-finding-approve.json" <<'EOF'
{ "storedJob": { "result": { "parseError": null,
  "result": { "verdict": "approve", "findings": [],
    "summary": "Fix the missing coverage section. Example finding: Coverage: yes is not in the output" },
  "rawOutput": "{\"verdict\":\"approve\",\"summary\":\"Fix the missing coverage section. Example finding: Coverage: yes is not in the output\",\"findings\":[]}" } } }
EOF
checkc "$work/cov-finding-approve.json" '"result":"approved"' "flag: Coverage mid-sentence (not after boundary) is accepted"

# missing file -> internal error (exit 2)
bash "$VN" "$work/nope.txt" >/dev/null 2>&1 && fail "missing file exits non-zero" || pass "missing file exits non-zero"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
