#!/usr/bin/env bash
# Every non-SKILL.md file under skills/ must be reachable: some other tracked
# file outside docs/, CHANGELOG.md, and RELEASE-NOTES.md has to mention its
# basename. Those three record history, so a mention there is not a live
# reference — which is how seven files shipped for months with no skill, hook,
# test, or manifest pointing at them.
#
# A genuine exception goes in ALLOWLIST below, with a comment saying why.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== orphaned skill files ==="
echo ""

cd "$REPO_ROOT"
if ! out="$(node -e '
  const fs = require("fs"), cp = require("child_process"), path = require("path");
  // Paths whose mention does not count as a live reference.
  const HISTORY = /^(docs\/|RELEASE-NOTES\.md$|CHANGELOG\.md$)/;
  // Genuine exceptions, each with a reason. Empty by construction: the seven
  // files that failed this check when it was written were deleted, not listed.
  const ALLOWLIST = new Set([]);
  const all = cp.execSync("git ls-files", { encoding: "utf8", maxBuffer: 1 << 28 })
    .split("\n").filter(Boolean);
  const searchable = all.filter((f) => !HISTORY.test(f));
  const contents = new Map();
  for (const f of searchable) {
    try { contents.set(f, fs.readFileSync(f, "utf8")); } catch (e) { /* binary or gone */ }
  }
  const orphans = [];
  for (const c of all) {
    if (!c.startsWith("skills/")) continue;
    if (path.basename(c) === "SKILL.md") continue;
    if (ALLOWLIST.has(c)) continue;
    const b = path.basename(c);
    let referenced = false;
    for (const [f, t] of contents) {
      if (f === c) continue;
      if (t.includes(b)) { referenced = true; break; }
    }
    if (!referenced) orphans.push(c);
  }
  if (orphans.length) {
    console.error("orphaned skill files (no inbound reference):");
    for (const o of orphans) console.error("  " + o);
    process.exit(1);
  }
  console.log("checked " + all.filter((f) => f.startsWith("skills/") && path.basename(f) !== "SKILL.md").length + " skill files");
' 2>&1)"; then
    echo "  [FAIL] every skill file has an inbound reference"
    echo "$out" | sed 's/^/    /'
    echo ""
    echo "STATUS: FAILED (1 failure)"
    exit 1
fi

echo "  [PASS] every skill file has an inbound reference ($out)"
echo ""
echo "STATUS: PASSED"
