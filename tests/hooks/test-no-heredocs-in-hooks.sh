#!/usr/bin/env bash
# Heredocs and here-strings are banned in hooks/ executables, and here-strings
# in the shell files under tests/. bash 5.1+ delivers a heredoc or a here-string
# through a pipe it writes before forking; under macOS pipe pressure the kernel
# hands out 512-byte pipes and that write deadlocks, hanging every hook in the
# session (https://github.com/obra/superpowers/issues/571) or a suite run under
# a contributor's bash. printf replaces them in hooks; process substitution,
# `< <(printf '%s\n' "$var")`, in tests. Heredocs under tests/ are a known gap
# tracked separately.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# The here-string token, assembled so this file never contains the form it bans.
hs='<<''<'

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
printf '#!/usr/bin/env bash\ncat %s "x"\n' "$hs" > "$probe/hs-hook"
printf '#!/usr/bin/env bash\ncat << EOF\nx\nEOF\n' > "$probe/hd-hook"
printf '#!/usr/bin/env bash\nprintf "ran\\n"\ncat < /dev/null\n' > "$probe/ok-hook"
probe_offenders="$(heredoc_offenders "$probe" | tr ' ' '\n' | sort | xargs)"

if [ "$probe_offenders" = "hd-hook hs-hook" ]; then
    pass "the fence flags heredocs and here-strings and nothing else"
else
    fail "the fence flags heredocs and here-strings and nothing else (got: ${probe_offenders:-<empty>})"
fi

# --- tests/: no here-strings ---
# A line whose first non-blank character is # is a comment and may name the form.
herestring_offenders() { # <file>... -> "<file>:<line>" for each offending line
    awk -v hs="$hs" 'index($0, hs) > 0 && $0 !~ /^[[:space:]]*#/ { print FILENAME ":" FNR }' "$@"
}
tests_shell_files() { # every tracked shell file under tests/: a .sh name or a sh/bash shebang
    local f first shebang_re='^#!.*(/|[[:space:]])(ba)?sh([[:space:]]|$)'
    while IFS= read -r f; do
        case "$f" in
            *.sh) printf '%s\n' "$REPO_ROOT/$f" ;;
            *)
                first=""
                IFS= read -r first < "$REPO_ROOT/$f" 2>/dev/null || true
                if [[ "$first" =~ $shebang_re ]]; then
                    printf '%s\n' "$REPO_ROOT/$f"
                fi
                ;;
        esac
    done < <(git -C "$REPO_ROOT" ls-files -- tests)
}

test_files=()
while IFS= read -r f; do test_files+=("$f"); done < <(tests_shell_files)
tests_offenders=""
if [ "${#test_files[@]}" -gt 0 ]; then
    tests_offenders="$(herestring_offenders "${test_files[@]}")"
fi
if [ "${#test_files[@]}" -eq 0 ]; then
    fail "no shell files found under tests/"
elif [ -z "$tests_offenders" ]; then
    pass "no shell file under tests/ uses a here-string (${#test_files[@]} files)"
else
    fail "here-string found under tests/: $(printf '%s' "$tests_offenders" | tr '\n' ' ')"
fi

printf '#!/usr/bin/env bash\ngrep -q x %s "$y"\n' "$hs" > "$probe/hs-test.sh"
printf '#!/usr/bin/env bash\n# a comment may name %s\necho ok\n' "$hs" > "$probe/comment-test.sh"
probe_test_offenders="$(herestring_offenders "$probe/hs-test.sh" "$probe/comment-test.sh")"
if [ "$probe_test_offenders" = "$probe/hs-test.sh:2" ]; then
    pass "the tests/ fence flags a here-string and not a comment naming one"
else
    fail "the tests/ fence flags a here-string and not a comment naming one (got: ${probe_test_offenders:-<empty>})"
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
