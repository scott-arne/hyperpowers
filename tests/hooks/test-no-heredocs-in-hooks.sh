#!/usr/bin/env bash
# Heredocs are banned in hooks/ executables. bash 5.1+ delivers a heredoc via a
# pre-fork pipe write; under macOS pipe pressure the kernel hands out 512-byte
# pipes and the write deadlocks, hanging every hook in the session. See
# https://github.com/obra/superpowers/issues/571. printf is the replacement.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== hooks heredoc fence ==="
echo ""

offenders=""
for f in "$REPO_ROOT"/hooks/*; do
    [ -f "$f" ] || continue
    # `<<` opens a heredoc; `<<<` is a here-string and writes no pipe.
    if grep -Eq '<<[^<]' "$f"; then
        offenders="$offenders $(basename "$f")"
    fi
done

if [ -z "$offenders" ]; then
    pass "no hooks/ file opens a heredoc"
else
    fail "heredoc found in hooks/:$offenders"
fi

# The wrapper must still be a working Unix launcher.
probe="$(mktemp -d)"
trap 'rm -rf "$probe"' EXIT
cp "$REPO_ROOT/hooks/run-hook.cmd" "$probe/run-hook.cmd"
printf '#!/usr/bin/env bash\nprintf "ran:%%s\\n" "$1"\n' > "$probe/probe-hook"
chmod +x "$probe/run-hook.cmd" "$probe/probe-hook"

if out="$(bash "$probe/run-hook.cmd" probe-hook arg1 2>&1)" && [ "$out" = "ran:arg1" ]; then
    pass "wrapper execs the named script with its arguments"
else
    fail "wrapper exec (got: ${out:-<empty>})"
fi

if out="$(bash "$probe/run-hook.cmd" 2>&1)" && [ -z "$out" ]; then
    pass "wrapper exits 0 silently with no script name"
else
    fail "wrapper with no arguments (got: ${out:-<empty>})"
fi

echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
