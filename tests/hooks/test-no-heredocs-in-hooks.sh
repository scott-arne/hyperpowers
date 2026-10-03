#!/usr/bin/env bash
# Heredocs are banned in hooks/ executables. bash 5.1+ delivers a heredoc via a
# pre-fork pipe write; under macOS pipe pressure the kernel hands out 512-byte
# pipes and the write deadlocks, hanging every hook in the session. See
# https://github.com/obra/superpowers/issues/571. bash 5.1+ delivers a
# here-string (`<<<`) the same way, so here-strings are banned too. printf is
# the replacement.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

echo "=== hooks heredoc fence ==="
echo ""

heredoc_offenders() { # <dir> -> the offending basenames in <dir>
    local dir="$1" f found=""
    for f in "$dir"/*; do
        [ -f "$f" ] || continue
        # `<<` opens a heredoc and `<<<` a here-string; both are pre-fork pipe
        # writes on bash 5.1+.
        if grep -Eq '(^|[^<])<<' "$f"; then
            found="$found $(basename "$f")"
        fi
    done
    printf '%s' "$found"
}

offenders="$(heredoc_offenders "$REPO_ROOT/hooks")"

if [ -z "$offenders" ]; then
    pass "no hooks/ file opens a heredoc or a here-string"
else
    fail "heredoc or here-string found in hooks/:$offenders"
fi

probe="$(mktemp -d)"
trap 'rm -rf "$probe"' EXIT

# A fence that flagged nothing would pass the case above just as loudly, so
# give it one of each form and one file with neither. This runs before the
# wrapper fixtures are copied in, so the expected offender list is exactly the
# two probes. printf writes them — this suite opens no heredoc either.
printf '#!/usr/bin/env bash\ncat <<< "x"\n' > "$probe/hs-hook"
printf '#!/usr/bin/env bash\ncat << EOF\nx\nEOF\n' > "$probe/hd-hook"
printf '#!/usr/bin/env bash\nprintf "ran\\n"\ncat < /dev/null\n' > "$probe/ok-hook"
probe_offenders="$(heredoc_offenders "$probe" | tr ' ' '\n' | sort | xargs)"

if [ "$probe_offenders" = "hd-hook hs-hook" ]; then
    pass "the fence flags heredocs and here-strings and nothing else"
else
    fail "the fence flags heredocs and here-strings and nothing else (got: ${probe_offenders:-<empty>})"
fi

# The wrapper must still be a working Unix launcher.
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
