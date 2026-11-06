#!/usr/bin/env bash
# Runs the documentation drift and content checks over this repository's
# docs/site/. The rules live in tests/docs/docs-check.sh; its fixture test
# is tests/docs/test-docs-check.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== docs-check over docs/site ==="
bash "$SCRIPT_DIR/docs-check.sh"
