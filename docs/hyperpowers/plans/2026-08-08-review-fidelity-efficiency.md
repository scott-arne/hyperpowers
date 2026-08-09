# Review Fidelity & Efficiency (SP3a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make gate round 1 discover the full breadth of blocking findings — lens fan-out over a generated review dossier, with a normalizer-enforced coverage floor — while delivering adjudications, document content, and test evidence to reviewers instead of having them fetch.

**Architecture:** One new context-assembly checker (`review-dossier`), a flag-gated extension to the existing approval authority (`verdict-normalize --require-coverage`), a one-line telemetry addition, and gate-doc amendments that recompose round 1 as dossier → lens fan-out → per-lens normalization → all-captures merge. Nothing that exits the loop changes; only what a round sees.

**Tech Stack:** bash + node built-ins only (no jq). Tests are bash scripts under `tests/`.

**Source spec:** `docs/hyperpowers/specs/2026-08-08-review-fidelity-efficiency-design.md`

## Global Constraints

- Script contract (6.3.0 discipline): exit 0 for every determinate answer with single-line JSON on stdout; exit 2 only for usage/internal errors. `chmod +x` new scripts; `bash scripts/lint-shell.sh` stays clean.
- `verdict-normalize` remains the ONLY approval authority; `gate-round` the only round authority; ledger appends, backstop ceilings, sweep semantics, and all existing Red Flags untouched.
- One `gate-round` call per LOGICAL round; the lens batch consumes a single round.
- Dossier sections: fixed order, fixed headers, ALWAYS all five present; per-file inline cap exactly 4000 lines with `TRUNCATED at line 4000 of M` markers; two absence markers — `NOT APPLICABLE: <why>` (input the gate type does not expect) vs `NOT PROVIDED: <flag not passed | file unreadable: path>` (expected input missing).
- Per-gate expected-inputs map (spec §4.1): spec/plan gates expect documents + adjudications (test evidence NOT APPLICABLE); task/adhoc gates expect adjudications + test evidence + base/head (documents NOT APPLICABLE); final gates expect all four.
- `--require-coverage` binds EVERY approve path (text AND structured JSON via raw review text) and is byte-identical when absent; `blocking`/`needs-attention` outcomes unaffected by the flag.
- Approval set wording: "every capture required for the latest round" — round 1 = every lens capture; re-review round = its single capture; an EMPTY capture set never approves.
- Plan-gate Algorithm Assessment attaches to the feasibility-and-contracts lens ONLY; adjudication/lock before the approval set is evaluated; all pre-existing Assessment needles stay green.
- Document-gate lenses run SEQUENTIALLY in the FOREGROUND; the "never background a document review" Red Flag stands unmodified.
- Needle rule: every needle phrase is a substring of ONE source line in the amended docs.
- Dossier fallback is hand-back attribution + artifact-presence trail — deliberately NOT an ungated-ledger event.
- No AI-attribution lines; never commit `docs/hyperpowers/` files; stage ONLY task files (never `git add -A` except the bump task's documented exclusion form); per-task commits per SDD cadence with branch-level diff approval before merge.
- Version bump to 6.5.0 only in the final task via `scripts/bump-version.sh`.
- The spec's candidate eval scenario (two doc-lens invocations + merged ledger, stub companion) is DELIBERATELY DEFERRED this release — needles + controller micro-tests are the bar (spec §3 non-goals allow this); revisit alongside SP3b's eval work.

---

### Task 1: `review-dossier` — one context artifact per gate

**Files:**
- Create: `skills/requesting-code-review/scripts/review-dossier`
- Test: `tests/codex-review-gate/test-review-dossier.sh`

**Interfaces:**
- Consumes: nothing (leaf utility; uses git for the changed-surfaces section).
- Produces (Tasks 4–5 and the gate doc rely on these exactly):
  `review-dossier --gate spec|plan|task|final|adhoc --out GATE_DIR [--doc PATH]... [--spec PATH] [--adjudications PATH]... [--test-evidence PATH]... [--base SHA --head SHA] [repo-dir]`
  → writes `GATE_DIR/dossier.md`, prints `{"ok":true,"dossier":"<path>","sections":5,"missing":M}` (M = NOT-PROVIDED section count), exit 0; exit 2 usage/internal. Section headers, verbatim: `## Documents under review`, `## Adjudicated decisions`, `## Test evidence`, `## Changed surfaces`, `## Review package`.

- [ ] **Step 1: Write the failing test**

Create `tests/codex-review-gate/test-review-dossier.sh`:

```bash
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

# usage errors -> exit 2
bash "$RD" --gate bogus --out "$gd" "$repo" >/dev/null 2>&1 && fail "bad gate exits 2" || pass "bad gate exits 2"
bash "$RD" --gate spec "$repo" >/dev/null 2>&1 && fail "missing --out exits 2" || pass "missing --out exits 2"

echo
[ "$FAILURES" -eq 0 ] && { echo "ALL PASS"; exit 0; } || { echo "$FAILURES FAILURES"; exit 1; }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/codex-review-gate/test-review-dossier.sh`
Expected: FAIL (script missing), non-zero exit.

- [ ] **Step 3: Write the implementation**

Create `skills/requesting-code-review/scripts/review-dossier`:

```bash
#!/usr/bin/env bash
# review-dossier — assemble one structured context artifact per gate
# (spec 4.1). Reviewers receive, rather than fetch: documents (inlined,
# line-numbered), adjudicated decisions, executed test evidence, and the
# changed-surfaces map, in five fixed sections that are ALWAYS present.
#
# Absence is two distinct markers driven by a per-gate expected-inputs
# map: NOT APPLICABLE (the gate type does not expect that input — quiet)
# vs NOT PROVIDED (an expected input is missing/unreadable — reviewers
# treat as cannot-verify). Inlines are capped at 4000 lines per file with
# an explicit TRUNCATED marker; no silent cuts.
#
# Usage:
#   review-dossier --gate spec|plan|task|final|adhoc --out GATE_DIR
#     [--doc PATH]... [--spec PATH] [--adjudications PATH]...
#     [--test-evidence PATH]... [--base SHA --head SHA] [repo-dir]
# stdout: {"ok":true,"dossier":"...","sections":5,"missing":M}
# Exit 0 determinate; exit 2 usage/internal.
set -uo pipefail

command -v node >/dev/null 2>&1 || { echo "review-dossier: node not found" >&2; exit 2; }

gate=""; out=""; repo="."
docs=(); adjs=(); evs=(); base=""; head=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) gate="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --doc|--spec) docs+=("$2"); shift 2 ;;
    --adjudications) adjs+=("$2"); shift 2 ;;
    --test-evidence) evs+=("$2"); shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --head) head="$2"; shift 2 ;;
    -*) echo "review-dossier: unknown flag $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done
case "$gate" in spec|plan|task|final|adhoc) : ;; *)
  echo "review-dossier: --gate must be spec|plan|task|final|adhoc" >&2; exit 2 ;; esac
[ -n "$out" ] && [ -d "$out" ] || { echo "review-dossier: --out GATE_DIR required and must exist" >&2; exit 2; }

# Changed surfaces are computed here (bash owns git) and handed to node.
changed=""
if [ -n "$base" ] && [ -n "$head" ]; then
  changed="$( { git -C "$repo" diff --stat "$base..$head" 2>&1 && git -C "$repo" diff --name-status "$base..$head" 2>&1; } )" \
    || changed="GIT ERROR: could not compute $base..$head"
fi

node -e '
  const fs = require("fs");
  const [gate, outDir, base, head, changed, docsCsv, adjsCsv, evsCsv] = process.argv.slice(1);
  const split = (s) => (s === "" ? [] : s.split(""));
  const docs = split(docsCsv), adjs = split(adjsCsv), evs = split(evsCsv);
  const CAP = 4000;

  // Per-gate expected-inputs map (spec 4.1).
  const expects = {
    spec:  { documents: true,  adjudications: true,  evidence: false, range: false },
    plan:  { documents: true,  adjudications: true,  evidence: false, range: false },
    task:  { documents: false, adjudications: true,  evidence: true,  range: true },
    adhoc: { documents: false, adjudications: true,  evidence: true,  range: true },
    final: { documents: true,  adjudications: true,  evidence: true,  range: true },
  }[gate];

  let missing = 0;
  const notProvided = (why) => { missing++; return `NOT PROVIDED: ${why}\n`; };
  const notApplicable = (why) => `NOT APPLICABLE: ${why}\n`;

  const inlineFiles = (paths, expected, kindWhy) => {
    if (paths.length === 0) {
      return expected ? notProvided("flag not passed") : notApplicable(kindWhy);
    }
    let outText = "";
    for (const p of paths) {
      let body;
      try { body = fs.readFileSync(p, "utf8"); }
      catch (e) { outText += notProvided(`file unreadable: ${p}`); continue; }
      const lines = body.split("\n");
      const total = lines[lines.length - 1] === "" ? lines.length - 1 : lines.length;
      const shown = Math.min(total, CAP);
      outText += `### ${p}\n\n`;
      for (let i = 0; i < shown; i++) outText += `\t${i + 1}\t${lines[i]}\n`;
      if (total > CAP) outText += `TRUNCATED at line ${CAP} of ${total}\n`;
      outText += "\n";
    }
    return outText;
  };

  let md = "# Review dossier\n\n";
  md += `Gate: ${gate}\n\n`;
  md += "## Documents under review\n\n";
  md += inlineFiles(docs, expects.documents, "this gate type reviews a diff, not documents");
  md += "\n## Adjudicated decisions\n\n";
  md += inlineFiles(adjs, expects.adjudications, "no adjudications for this gate type");
  md += "\n## Test evidence\n\n";
  md += inlineFiles(evs, expects.evidence, "document gates carry no executed-test evidence");
  md += "\n## Changed surfaces\n\n";
  if (changed !== "") md += changed + "\n";
  else md += expects.range ? notProvided("flag not passed (--base/--head)") : notApplicable("document gates have no commit range");
  md += "\n## Review package\n\n";
  md += (gate === "spec" || gate === "plan")
    ? "not applicable (document gate; the documents above ARE the artifact)\n"
    : "the companion-assembled diff for --base above is the review package; this dossier supplements it\n";

  fs.writeFileSync(`${outDir}/dossier.md`, md);
  process.stdout.write(JSON.stringify({ ok: true, dossier: `${outDir}/dossier.md`, sections: 5, missing }) + "\n");
' "$gate" "$out" "$base" "$head" "$changed" \
  "$(IFS=$''; echo "${docs[*]-}")" \
  "$(IFS=$''; echo "${adjs[*]-}")" \
  "$(IFS=$''; echo "${evs[*]-}")" \
  || { echo "review-dossier: assembly failed" >&2; exit 2; }
```

Then: `chmod +x skills/requesting-code-review/scripts/review-dossier`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/codex-review-gate/test-review-dossier.sh`
Expected: `ALL PASS`. `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/review-dossier tests/codex-review-gate/test-review-dossier.sh
git commit -m "feat(gate): review-dossier assembles delivered context per gate"
```

---

### Task 2: `verdict-normalize --require-coverage`

**Files:**
- Modify: `skills/requesting-code-review/scripts/verdict-normalize`
- Modify: `tests/codex-review-gate/test-verdict-normalize.sh`

**Interfaces:**
- Consumes: the existing script's structure (bash wrapper, embedded node; text path via `parseText`, JSON path via `fromStructured` with rawOutput fallback).
- Produces: `verdict-normalize [--require-coverage] <payload-file>` — with the flag, EVERY approve path requires a `Coverage:`/`## Coverage` heading followed by non-whitespace content: the text path checks the document text; the structured-JSON path checks the payload's raw review text (`.storedJob.result.rawOutput`, else `.storedJob.result.codex.stdout`) BEFORE honoring a structured approve. Failure → `{"result":"incomplete",...,"reason":"...approve without coverage evidence"}`. Without the flag: byte-identical to today. Tasks 4–5's gate-doc text names this flag exactly.

- [ ] **Step 1: Write the failing tests**

Append to `tests/codex-review-gate/test-verdict-normalize.sh`, before the missing-file case, following the file's `check` helper style (note: `check` runs without the flag; add a flagged variant):

```bash
checkc() { # with --require-coverage: <file> <fragment> <desc>
  local out; out="$(bash "$VN" --require-coverage "$1")"
  printf '%s' "$out" | grep -Fq "$2" && pass "$3" || fail "$3 (got: $out)"
}

# --- coverage floor (--require-coverage) ---
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
```

- [ ] **Step 2: Run to verify the new checks fail**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh`
Expected: the `checkc` coverage cases FAIL (unknown flag → exit 2 or wrong result); every pre-existing check PASSES.

- [ ] **Step 3: Implement the flag**

In `skills/requesting-code-review/scripts/verdict-normalize`:

(a) Bash wrapper: accept the flag before the file argument and pass it to node as argv:

```bash
require_coverage=0
if [ "${1:-}" = "--require-coverage" ]; then require_coverage=1; shift; fi
```

and invoke node with the flag appended AFTER the existing file argument (`... "$file" "$require_coverage"`), updating the header comment's usage line to `verdict-normalize [--require-coverage] <payload-file>`.

(b) Node core: the payload file is `process.argv[1]` in this `node -e` script, so the flag lands at index 2 — read it as `const requireCoverage = process.argv[2] === "1";`. Add one helper near the top:

```javascript
  // Coverage floor (spec 4.5): with --require-coverage, an approve is only
  // honored when the review text carries a Coverage heading with content —
  // on the text path the document itself, on the JSON path the payload's
  // raw review text. Adds a way to be incomplete, never a way to approve.
  const coverageOk = (t) =>
    /^(##\s*)?Coverage:?[ \t]*\n(?=[\s\S]*?\S)(?![ \t]*\n[ \t]*\n[ \t]*(Verdict|Summary|##))/m.test(t) &&
    /^(##\s*)?Coverage:?[ \t]*$[\s\S]*?\S/m.test(t.slice(t.search(/^(##\s*)?Coverage:?/m)));
```

Implementer note: the intent is simpler than regex golf — locate the first `Coverage:`/`## Coverage` heading; require that the text between it and the next `Summary:`/`Verdict:`/`##` heading (or end) contains non-whitespace. If the double-regex above proves brittle in testing, implement it as two steps (indexOf the heading, slice to the next section boundary, test `\S`) — the TESTS define the contract, keep them exact.

(c) Text path: in `parseText`, in the approve-with-zero-blocking branch, before `out("approved", ...)`:

```javascript
    if (verdict === "approve" && blocking === 0) {
      if (requireCoverage && !coverageOk(t))
        out("incomplete", "approve", 0, source + ": approve without coverage evidence");
      out("approved", "approve", 0, source + ": approve, no blocking findings");
    }
```

(d) JSON path: in `fromStructured`, in the approve-with-zero-blocking branch, before returning approved, check the payload's raw text (thread it in — give `fromStructured` a second parameter `raw`):

```javascript
    if (v.verdict === "approve" && blocking === 0) {
      if (requireCoverage && !coverageOk(raw || ""))
        out("incomplete", "approve", 0, source + ": approve without coverage evidence");
      out("approved", "approve", 0, source + ": approve, no blocking findings");
    }
```

with callers passing `raw = (d.storedJob?.result?.rawOutput) || (d.storedJob?.result?.codex?.stdout) || ""` (adapt to the file's actual optional-chaining style — it currently uses `&&` chains).

- [ ] **Step 4: Run to verify green**

Run: `bash tests/codex-review-gate/test-verdict-normalize.sh` — ALL PASS (every pre-existing check plus the new coverage matrix). Re-run the two real-file regressions from the file's existing steps (spec-gate captures → approved/0 and blocking/2, both WITHOUT the flag) — unchanged. `bash scripts/lint-shell.sh` clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/verdict-normalize tests/codex-review-gate/test-verdict-normalize.sh
git commit -m "feat(gate): flag-gated coverage floor on every approve path"
```

---

### Task 3: telemetry dossier-presence count

**Files:**
- Modify: `skills/requesting-code-review/scripts/gate-telemetry`
- Modify: `tests/codex-review-gate/test-gate-telemetry.sh`

**Interfaces:**
- Consumes: Task 1's artifact name (`dossier.md` inside a gate run dir).
- Produces: per-repo metric `dossiers: <K>/<runs-with-round-data>` in markdown and `"dossiers":K` in `--json` (count of run dirs containing BOTH `gate-round.json` and `dossier.md`).

- [ ] **Step 1: Write the failing test additions**

In `tests/codex-review-gate/test-gate-telemetry.sh`, in the fixture setup after the `gate-round.json` files are written, add a dossier to exactly one parseable run:

```bash
printf '# Review dossier\n' > "$cr/run-aaa/dossier.md"
```

and assertions beside the existing metric checks:

```bash
expect "$md" 'Dossiers: 1/2' "dossier presence counted"
printf '%s' "$js" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));if(d.repos[0].dossiers!==1)process.exit(1)' \
  && pass "--json carries dossiers count" || fail "--json carries dossiers count"
```

- [ ] **Step 2: Run to verify the additions fail**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh` — the two new assertions FAIL, all prior pass.

- [ ] **Step 3: Implement**

In `gate-telemetry`'s node aggregator: initialize `r.dossiers = 0`; in the run-dir loop, after a `gate-round.json` parses successfully, add:

```javascript
      if (fs.existsSync(path.join(cr, run, "dossier.md"))) r.dossiers++;
```

Markdown line (beside the runs line): `- Dossiers: ${r.dossiers}/${r.runs}`; the JSON already serializes whole repo objects so no schema change beyond the field. REQUIRED, not conditional: the `--all` fleet aggregate gains an explicit `dossiers` sum (the aggregator is explicit-field, so add the field the same way `runs` is summed) and the fleet markdown gains its own `Dossiers: K/N` line. Add to the test's `--all` section: the fleet markdown contains `Dossiers: 1/2` and the `--all --json` aggregate carries `dossiers === 1` (extend the existing fleet assertions in the same style).

- [ ] **Step 4: Run to verify green**

Run: `bash tests/codex-review-gate/test-gate-telemetry.sh` — ALL PASS. Lint clean.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/scripts/gate-telemetry tests/codex-review-gate/test-gate-telemetry.sh
git commit -m "feat(gate): telemetry counts dossier presence per gate run"
```

---

### Task 4: Gate-doc §3 — dossier assembly + lens templates

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§3)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (new needles)

**Interfaces:**
- Consumes: Task 1's CLI exactly; the existing §3 recipes, round-counting sentence, and suppression lines (all preserved).
- Produces: the lens-prompt skeleton and per-gate charters Tasks 5's merge text references by name (lens names verbatim: `completeness-and-consistency`, `feasibility-and-scope`, `coverage-and-ordering`, `feasibility-and-contracts`, `correctness`, `contracts-and-integration`, `tests-and-evidence`, `integration-and-requirements-coverage`).

- [ ] **Step 1: Add the needles (RED)**

Append beside the other 6.4.0+ needles in `test-gate-contract.sh`:

```bash
echo "Review fidelity (6.5.0):"
assert_contains "$GATE" "scripts/review-dossier" "gate assembles a dossier"
assert_contains "$GATE" "Report every blocking finding you can identify this round; do not reserve findings for later rounds." "exhaustiveness demand"
assert_contains "$GATE" '[out-of-lane]' "out-of-lane findings are reported, never suppressed"
assert_contains "$GATE" "The lens batch consumes a single logical round" "one gate-round per logical round"
assert_contains "$GATE" "sequentially in the foreground" "doc lenses stay foreground"
assert_contains "$GATE" "Algorithm Assessment attaches to the feasibility-and-contracts lens" "assessment pinned to one lens"
assert_contains "$GATE" "falls back to the path-based prompts" "dossier degrade attributed"
```

Run the contract test: the 7 new needles FAIL; everything else (incl. all pre-existing Algorithm Assessment needles) PASSES. Record the tally.

- [ ] **Step 2: Insert the dossier-assembly step**

In §3, immediately AFTER the (amended) count-every-round paragraph — the round authority advances FIRST — insert:

```markdown
**Assemble the dossier — reviewers receive, rather than fetch.** Only a
`"verdict":"proceed"` from the logical round's `gate-round` call reaches
this step: on `backstop` or a non-zero exit, stop before assembling
anything (a stopped round leaves no `dossier.md`, keeping the
dossier-presence telemetry signal clean). On proceed, build the gate's
context artifact:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/review-dossier" --gate <spec|plan|task|final|adhoc> --out "$GATE_DIR" <inputs per the table below>
```

| Gate | Inputs to pass |
|------|----------------|
| spec | `--spec <spec path>` plus `--adjudications <path>` for any approved-design/decision context |
| plan | `--doc <plan path> --doc <spec path>` plus `--adjudications <spec-gate round ledger path>` |
| task/adhoc | `--adjudications <spec decision excerpts / spec-gate ledger> --test-evidence <implementer report path> --base <task BASE> --head <head sha>` |
| final | all of the above: plan/spec docs, ledgers, Minor ledger, branch `--base <merge-base> --head <head>` |

The dossier renders every expected-but-missing input as `NOT PROVIDED`
(reviewers treat that axis as cannot-verify) and gate-type-inapplicable
inputs as `NOT APPLICABLE`. If the dossier build itself fails, the gate
falls back with the failure named in the §6 hand-back — never blocked,
always attributed. **The fallback keeps the SAME approval contract:**
compose the same lens prompts with the dossier line replaced by the
original path-based context lines (the artifact/brief/report paths the
recipes name), so every fallback lens still carries the lens charter, the
exhaustiveness demand, and the required `Coverage:` section — its axes
answered from what the reviewer fetched — and round-1 fallback captures
are normalized with `verdict-normalize --require-coverage` exactly like
dossier-backed ones. One approval rule everywhere; the only thing a
fallback loses is delivered context.
```

- [ ] **Step 3: Replace the round-1 prompts with the lens fan-out**

Still in §3, replace the single spec/plan prompt templates and precede the code recipes with the fan-out contract. Insert this block (adjusting the existing template text it subsumes — the Required document-review output shape and the suppression lines are REUSED verbatim inside it):

```markdown
**Round 1 is a lens fan-out.** The lens batch consumes a single logical round: run `gate-round` once, then launch EVERY lens for this gate type over the same dossier. **This step also AMENDS the existing "Count every round — the first included." paragraph** (do not merely add alongside it — as written it requires `gate-round` before ANY companion invocation, which under fan-out would spend one round per lens): keep its opening phrase `Count every round — the first included.` intact (its needle must stay green) and reword its body to: "Before composing ANY LOGICAL round (round 1 included), run §5 step-0's `gate-round` counter once for this `GATE_DIR`; a round-1 lens batch counts as ONE round — individual lens launches within the batch do NOT advance the counter; only a `\"verdict\":\"proceed\"` may launch the batch (or the single re-review)." Per-gate lenses:

| Gate | Lenses |
|------|--------|
| spec | completeness-and-consistency; feasibility-and-scope |
| plan | coverage-and-ordering; feasibility-and-contracts |
| task/adhoc | correctness; contracts-and-integration; tests-and-evidence |
| final | correctness; integration-and-requirements-coverage; tests-and-evidence |

Each lens prompt file is composed from this skeleton (one prompt file per lens, `$GATE_DIR/lens-<name>-prompt.md`):

```markdown
Read the review dossier first — it is your delivered context: <GATE_DIR>/dossier.md
Where a dossier section says NOT PROVIDED, treat that axis as cannot-verify; where it says NOT APPLICABLE, answer that Coverage axis as such without hedging.
Your lens for this review: <one charter sentence from the table below>.
Report every blocking finding you can identify this round; do not reserve findings for later rounds.
Findings outside your lens are still reported, labeled [out-of-lane] — never suppressed.
You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills.
Do not edit anything. Return exactly the Required document-review output below, adding a Coverage: section before Summary with these axes, each answered concretely or marked not applicable: documents read; adjudicated decisions considered; changed surfaces reviewed; test evidence inspected.
<the existing Required document-review output block, verbatim>
```

Lens charters:

| Lens | Charter |
|------|---------|
| completeness-and-consistency | Every requirement present, unambiguous, and internally consistent; contradictions and gaps between sections. |
| feasibility-and-scope | Buildable as specified; scope fits one plan; hidden dependencies and unstated assumptions. |
| coverage-and-ordering | Every spec requirement maps to a task; task sizing and sequencing; nothing implemented before its dependency. |
| feasibility-and-contracts | Types, signatures, and interfaces consistent across tasks; each step executable as written. |
| correctness | Does the change do what its requirements say, and only that; logic, edge cases, failure paths. |
| contracts-and-integration | Interfaces honored; call sites, shared state, and cross-component effects of the diff. |
| tests-and-evidence | Do the tests prove the claims; is the executed evidence in the dossier consistent with the diff; gaps between claim and proof. |
| integration-and-requirements-coverage | Whole-branch: requirements coverage against the plan/spec, integration risk across tasks, Minor-ledger triage. |

**Document gates run their lenses sequentially in the foreground** (two `task --fresh` calls, each with the explicit 600000 ms timeout) — the existing Red Flag against backgrounding document reviews stands. **Code and final gates launch each lens as its own detached `adversarial-review`** (same recipe lines as below, with the lens prompt content as the focus context via the dossier + charter sentence appended to the focus string) and watch each via the §3 watch loop; concurrent where the companion permits, pipelined where it serializes — correctness is independent of interleaving.

**Plan gate only:** the Round-1 Algorithm Assessment attaches to the feasibility-and-contracts lens and ONLY that lens — append the existing assessment block (verbatim, unchanged trigger and output shape) to that lens's prompt; the coverage-and-ordering lens never emits an Assessment, and any algorithm opinion it volunteers is an ordinary finding. Adjudication and lock run at their existing point, before the approval set is evaluated.

**Re-review rounds (2+) use no lenses**: the existing single-reviewer round-aware preamble and ledger contract apply verbatim. The ORIGINAL single-review spec and plan prompt templates are NOT deleted by the fan-out replacement — they are retained under a `Re-review prompt (rounds 2+)` label immediately after the lens block, textually unchanged, and rounds 2+ compose from them exactly as today.
```

Preserve untouched: the recipes' command lines, the base-validation step, and all five suppression lines. The count-every-round paragraph is NOT preserved untouched — its body is REPLACED with the logical-round wording per the fan-out block above (opening phrase kept for its needle); the old "before ANY companion review invocation" body must not survive, and Step 1's needle set gains a negative assertion pinning that:

```bash
assert_not_contains "$GATE" "Before ANY companion review invocation in this section" "per-invocation counting is gone"
```

(making it 7 positive + 1 negative new needles; adjust the RED/GREEN tallies accordingly).

- [ ] **Step 4: Contract test GREEN**

Run: `bash tests/codex-review-gate/test-gate-contract.sh` — all needles pass: the 7 new, every pre-existing one (Algorithm Assessment set included). If any pre-existing needle broke, the replacement deleted contract text it must keep — restore it.

- [ ] **Step 5: Controller micro-tests (a) and (c)** — the controller runs these (implementer: note the deferral in your report):
(a) lens-lane discipline: a tool-less rep given the correctness charter + a dossier stimulus containing an obvious contracts bug must report it labeled `[out-of-lane]` while still covering its own lane; (c) a rep whose dossier says `NOT PROVIDED` for test evidence answers that Coverage axis cannot-verify rather than guessing. Both recorded in the execution ledger; wording tightened and re-probed once if either misreads.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): dossier assembly and round-1 lens fan-out in the gate doc"
```

---

### Task 5: Gate-doc §4b/§5 — per-lens normalization and the approval set

**Files:**
- Modify: `skills/requesting-code-review/codex-review-gate.md` (§4b, §5)
- Modify: `tests/codex-review-gate/test-gate-contract.sh` (needles, incl. one updated in place)

**Interfaces:**
- Consumes: Task 2's `--require-coverage` flag name exactly; Task 4's lens names; the existing §5 approval-set sentence and its needle.
- Produces: the merge contract the SDD/sweep flows execute.

- [ ] **Step 1: Needles (RED)**

```bash
assert_contains "$GATE" "verdict-normalize --require-coverage" "round-1 captures normalized with the coverage floor"
assert_contains "$GATE" "every capture required for the latest round" "approval set covers fan-out and re-review alike"
assert_contains "$GATE" "An empty capture set never approves" "empty set fails closed"
assert_contains "$GATE" '[lens:' "ledger entries carry lens tags"
```

Also UPDATE in place the existing merged-success needle (search the test for `every lens` — absent; search for the 6.4.0 phrase `for the latest round's captured output`): change its expected string to `every capture required for the latest round` with an updated description. RED run: 4 new + 1 updated FAIL; rest PASS.

- [ ] **Step 2: Amend §4b**

After the mechanical-normalization block, insert:

```markdown
**Round-1 lens captures.** Normalize every round-1 capture with `verdict-normalize --require-coverage` — the coverage floor is part of the approval authority. Capture each lens's output to its own file in
`GATE_DIR` and normalize each:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/verdict-normalize" --require-coverage "$GATE_DIR/lens-<name>-capture"
```

The round's verdict merges fail-closed: ALL lenses `approved` → the round
is approved. ANY lens `incomplete` — after per-lens recovery (the bounded
re-fetch above, plus at most one relaunch of THAT lens if the failure
looked transient) — → the round is incomplete: surviving lenses' blocking
findings still enter the round ledger as actionable work, but nothing
approves. Otherwise → blocking. Deduplicate findings into the ONE round
ledger (same file/section + same defect = one entry, all reporting lenses
credited); every entry carries its source tag `[lens: <name>]` (plus
`[out-of-lane]` where the lens said so). Re-review rounds normalize their
single capture WITHOUT the flag, exactly as today.
```

- [ ] **Step 3: Amend §5's approval set**

Rewrite the merged success condition (both the loop step-1 line and the stop-list bullet) so the approval object is the capture SET:

```markdown
The approval set is every capture required for the latest round: round 1's set is every lens capture; a re-review round's set is its single capture. An empty capture set never approves. The round converges only when EVERY capture in the set normalized `"result":"approved"`, this round raised no blocking findings, and the round ledger has no still-open blocking findings.
```

(keeping the existing no-blocking-findings and clean-ledger conjuncts and the subordination sentence verbatim; each needle phrase on one source line).

- [ ] **Step 4: GREEN + micro-test (b)**

Contract test: ALL PASS (4 new, 1 updated, all pre-existing). Micro-test (b), controller-run: a merge stimulus where two lenses report the same defect in the same file must dedupe to one ledger entry crediting both — recorded in the execution ledger.

- [ ] **Step 5: Companion concurrency check (live, recorded)**

Read the companion's job-runner source once (`/Users/johnss51/.claude/plugins/cache/openai-codex/codex/1.0.6/scripts/lib/` — the review job scheduling) to determine whether two `adversarial-review` jobs for one repo run concurrently or queue. If the source is unambiguous, record the answer + file:line in the task report. Only if genuinely ambiguous, run the live probe: launch two detached minimal reviews back-to-back (`--base HEAD~1`, focus "Concurrency probe; reply with Verdict: approve and a Coverage: section noting this is a probe. Do not edit anything.") and observe `status --json`'s `running[]` — record whether both appear running simultaneously. Either outcome is acceptable; the gate doc already reads correctly for both.

- [ ] **Step 6: Commit**

```bash
git add skills/requesting-code-review/codex-review-gate.md tests/codex-review-gate/test-gate-contract.sh
git commit -m "feat(gate): per-lens coverage-floored normalization and the capture-set approval rule"
```

---

### Task 6: Version bump + full sweep

**Files:**
- Modify: version-declared files via `scripts/bump-version.sh`

- [ ] **Step 1: Full sweep**

```bash
for t in tests/codex-review-gate/test-*.sh tests/hooks/test-*.sh; do
  echo "== $t"; bash "$t" || echo "FAILED: $t"
done
bash scripts/lint-shell.sh
```
ALL pass or the bump is blocked (report BLOCKED instead).

- [ ] **Step 2: Bump and audit**

`bash scripts/bump-version.sh 6.5.0` then `bash scripts/bump-version.sh --audit` — no stale 6.4.x in declared files.

- [ ] **Step 3: Commit and verify tree**

```bash
git add -A ':!docs/hyperpowers'
git commit -m "chore: bump 6.4.0 -> 6.5.0 for review fidelity and efficiency"
git status --short
```
Expected: only `docs/hyperpowers/` entries remain (the SP3a spec + this plan, uncommitted unless the user asks).
