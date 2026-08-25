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
#
# `-e` is deliberately absent: the link grep exits 1 when the index has no
# links yet, which is the correct pre-split state. Every write is therefore
# checked explicitly — a helper that reported success without producing an
# assembled view would silently disarm the tests that consume it.
set -uo pipefail

repo_root="${1:?usage: assemble-gate.sh <repo-root> <out-file>}"
out_file="${2:?usage: assemble-gate.sh <repo-root> <out-file>}"

gate_dir="$repo_root/skills/requesting-code-review"
index="$gate_dir/codex-review-gate.md"

if [ ! -f "$index" ]; then
  echo "assemble-gate: index not found: $index" >&2
  exit 1
fi

if ! : >"$out_file"; then
  echo "assemble-gate: cannot create output: $out_file" >&2
  exit 1
fi
if ! cat "$index" >>"$out_file"; then
  echo "assemble-gate: failed writing index to: $out_file" >&2
  exit 1
fi

# A same-directory .md link the discovery pattern below cannot parse — an
# uppercase letter, an underscore, a path prefix — would be skipped silently,
# dropping that sibling's content out of every downstream assertion without
# failing anything. Names outside lowercase-hyphen are a hard error instead.
unparseable="$(grep -o '](\([^)]*\.md\))' "$index" | sed 's/^](//; s/)$//' |
  grep -v '^[a-z0-9-]*\.md$' || true)"
if [ -n "$unparseable" ]; then
  echo "assemble-gate: index links a .md target outside the lowercase-hyphen namespace: $unparseable" >&2
  exit 1
fi

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
  if ! cat "$sibling" >>"$out_file"; then
    echo "assemble-gate: failed writing sibling $target to: $out_file" >&2
    exit 1
  fi
done < <(grep -o '](\([a-z0-9-]*\.md\))' "$index" | sed 's/^](//; s/)$//')
