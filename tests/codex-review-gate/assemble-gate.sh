#!/usr/bin/env bash
#
# assemble-gate.sh — emit the whole Codex review gate as one file.
#
# Usage: assemble-gate.sh <repo-root> <out-file>
#
# The gate is a dispatcher index (codex-review-gate.md) plus section-file
# siblings in the same directory. Content assertions must run against the
# union, not the index; otherwise splitting the document would silently
# empty them out. Siblings are discovered from the index's own markdown
# links, so this stays correct as files are added or renamed, and a
# dangling link is a hard error rather than a silent omission.
set -uo pipefail

repo_root="${1:?usage: assemble-gate.sh <repo-root> <out-file>}"
out_file="${2:?usage: assemble-gate.sh <repo-root> <out-file>}"

gate_dir="$repo_root/skills/requesting-code-review"
index="$gate_dir/codex-review-gate.md"

if [ ! -f "$index" ]; then
  echo "assemble-gate: index not found: $index" >&2
  exit 1
fi

: >"$out_file"
cat "$index" >>"$out_file"

# Same-directory .md link targets, in the order they appear, deduplicated.
seen=" "
while IFS= read -r target; do
  case "$seen" in *" $target "*) continue ;; esac
  seen="$seen$target "
  sibling="$gate_dir/$target"
  if [ ! -f "$sibling" ]; then
    echo "assemble-gate: index links a missing sibling: $target" >&2
    exit 1
  fi
  cat "$sibling" >>"$out_file"
done < <(grep -o '](\([a-z0-9-]*\.md\))' "$index" | sed 's/^](//; s/)$//')
