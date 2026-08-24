#!/usr/bin/env bash
#
# Losslessness proof for the codex-review-gate.md split.
#
# The gate document was split into a dispatcher index plus nine section
# files. This check proves the move lost nothing. It reads the pre-split
# original out of git at a pinned commit, reconstructs every destination
# file from the declared line ranges plus the declared positional-reference
# rewrites and the declared post-split edits, and requires byte-identity.
#
# The gate contract test cannot do this job: it normalizes whitespace and
# only pins selected substrings, so it would still pass after reordering,
# duplication, or the loss of any line no assertion happens to name.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE_DIR="$REPO_ROOT/skills/requesting-code-review"
MANIFEST="$SCRIPT_DIR/gate-split-manifest.tsv"
REFERENCES="$SCRIPT_DIR/gate-split-references.tsv"
POST_EDITS="$SCRIPT_DIR/gate-post-split-edits.tsv"

# Pinned pre-split commit. The original file is read from git, so it stays
# available no matter what happens to the working tree.
ORIGIN_SHA="9242d4f6bdcdbf373548a8197b515a2e309de03b"
ORIGIN_PATH="skills/requesting-code-review/codex-review-gate.md"
ORIGIN_LINES=766
UNTRACKED_BLANKS=(273 356)
TAB="$(printf '\t')"

failures=0
passes=0
skips=0
pass() {
    echo "  [PASS] $1"
    passes=$((passes + 1))
}
skip() {
    echo "  [SKIP] $1"
    skips=$((skips + 1))
}
fail() {
    echo "  [FAIL] $1"
    failures=$((failures + 1))
}

TEST_ROOT="$(mktemp -d)" || { echo "  [FAIL] cannot create scratch directory" >&2; exit 1; }
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

original="$TEST_ROOT/original.md"
if ! git -C "$REPO_ROOT" show "$ORIGIN_SHA:$ORIGIN_PATH" >"$original" 2>/dev/null; then
    echo "  [FAIL] cannot read pinned original $ORIGIN_SHA:$ORIGIN_PATH"
    exit 1
fi

echo "=== gate split losslessness ==="
echo ""

# --- 1. The pinned original is the file we planned against. ---
actual_lines="$(wc -l <"$original" | tr -d ' ')"
if [ "$actual_lines" = "$ORIGIN_LINES" ]; then
    pass "pinned original is $ORIGIN_LINES lines"
else
    fail "pinned original is $ORIGIN_LINES lines (got $actual_lines)"
fi

# --- 2. The declared ranges tile 1..766, gaps only at declared blanks. ---
covered="$TEST_ROOT/covered"
: >"$covered"
overlap=0
while IFS="$TAB" read -r dest start end; do
    case "$dest" in \#* | "") continue ;; esac
    seq "$start" "$end" >>"$covered"
done <"$MANIFEST"
total="$(wc -l <"$covered" | tr -d ' ')"
sort -n "$covered" | uniq >"$covered.sorted"
uniq_total="$(wc -l <"$covered.sorted" | tr -d ' ')"
[ "$total" = "$uniq_total" ] || overlap=1
if [ "$overlap" -eq 0 ]; then
    pass "no line is claimed by two destinations"
else
    fail "no line is claimed by two destinations ($((total - uniq_total)) duplicated)"
fi

expected="$TEST_ROOT/expected"
seq 11 "$ORIGIN_LINES" >"$expected"
for b in "${UNTRACKED_BLANKS[@]}"; do
    grep -vx "$b" "$expected" >"$expected.tmp" && mv "$expected.tmp" "$expected"
done
sort -n "$expected" -o "$expected"
if diff -q "$expected" "$covered.sorted" >/dev/null; then
    pass "ranges tile lines 11-$ORIGIN_LINES exactly (1-10 stay in the index; ${UNTRACKED_BLANKS[*]} untracked)"
else
    fail "ranges tile lines 11-$ORIGIN_LINES exactly"
    diff "$expected" "$covered.sorted" | head -20
fi

# --- 3. The positional-reference candidate set is exhaustive. ---
# Independent enumeration: every line naming a relative position, plus the
# composer instruction that points at the output block without using
# "below". If a future edit adds a positional reference, this fails and the
# table must be updated rather than the count.
grep -n 'below\|above' "$original" | cut -d: -f1 >"$TEST_ROOT/grep-hits"
grep -n '^<the existing .*verbatim>$' "$original" | cut -d: -f1 >>"$TEST_ROOT/grep-hits"
sort -n "$TEST_ROOT/grep-hits" | uniq >"$TEST_ROOT/candidates"
grep -v '^#' "$REFERENCES" | grep -v '^$' | cut -f1 | sort -n >"$TEST_ROOT/tabled"
if diff -q "$TEST_ROOT/candidates" "$TEST_ROOT/tabled" >/dev/null; then
    pass "reference table covers every positional-reference candidate"
else
    fail "reference table covers every positional-reference candidate"
    diff "$TEST_ROOT/candidates" "$TEST_ROOT/tabled"
fi

# --- 4. Disposition is DERIVED, not trusted. ---
# A reference is a rewrite if and only if its referent lands in a different
# destination than the reference itself. Referent "-" means the reference
# describes the generated prompt's own layout, never the source document,
# so it is always verbatim.
dest_of() {
    local line="$1"
    [ "$line" -le 10 ] && { echo "codex-review-gate.md"; return; }
    while IFS="$TAB" read -r d s e; do
        case "$d" in \#* | "") continue ;; esac
        if [ "$line" -ge "$s" ] && [ "$line" -le "$e" ]; then
            echo "$d"
            return
        fi
    done <"$MANIFEST"
    echo "UNMAPPED"
}

bad_disposition=0
while IFS="$TAB" read -r src referent disposition _replacement; do
    case "$src" in \#* | "") continue ;; esac
    if [ "$referent" = "-" ]; then
        derived="verbatim"
    elif [ "$(dest_of "$src")" = "$(dest_of "$referent")" ]; then
        derived="verbatim"
    else
        derived="rewrite"
    fi
    if [ "$derived" != "$disposition" ]; then
        echo "    line $src: table says $disposition, derivation says $derived"
        bad_disposition=$((bad_disposition + 1))
    fi
done <"$REFERENCES"
if [ "$bad_disposition" -eq 0 ]; then
    pass "every disposition matches the derivation from the manifest"
else
    fail "every disposition matches the derivation from the manifest ($bad_disposition wrong)"
fi

rewrite_count="$(grep -v '^#' "$REFERENCES" | grep -c "$(printf '\trewrite\t')")"
if [ "$rewrite_count" -eq 8 ]; then
    pass "exactly 8 cross-file rewrites, as designed"
else
    fail "exactly 8 cross-file rewrites, as designed (got $rewrite_count)"
fi

# awk -v reinterprets backslash escapes in the value it is given, and BOTH the
# split script and this verifier substitute through awk -v — so a mangled
# replacement would appear identically on each side and pass unnoticed. None of
# the eight replacements contains a backslash today; keep it that way.
# shellcheck disable=SC1003  # the literal backslash is the pattern, not an escape
if grep -v '^#' "$REFERENCES" | cut -f4 | grep -qF '\'; then
    fail "no replacement text contains a backslash (awk -v would reinterpret it)"
else
    pass "no replacement text contains a backslash"
fi

# --- 4b. Intentional post-split edits are declared and in range. ---
# Not every content edit is a positional reference, and the references table is
# the wrong home for one that is not: its candidate set is a grep of the
# original for "below|above" (check 3) and its rewrite count is pinned at 8
# (check 4). This second table is the channel for those edits, held to the same
# standard — every byte of every section file still traces to an original line,
# a declared positional rewrite, or a declared edit here.
bad_edit=0
post_edit_count=0
while IFS="$TAB" read -r src _reason replacement; do
    case "$src" in \#* | "") continue ;; esac
    post_edit_count=$((post_edit_count + 1))
    edit_dest="$(dest_of "$src")"
    case "$edit_dest" in
    codex-review-gate.md | UNMAPPED)
        echo "    line $src: outside every declared section range (resolves to $edit_dest)"
        bad_edit=$((bad_edit + 1))
        continue
        ;;
    esac
    # A row that changes nothing is a lie in the audit trail: it claims an edit
    # the reconstruction cannot show.
    if [ "$replacement" = "$(sed -n "${src}p" "$original")" ]; then
        echo "    line $src: replacement is identical to the original line"
        bad_edit=$((bad_edit + 1))
    fi
done <"$POST_EDITS"
if [ "$bad_edit" -eq 0 ]; then
    pass "every post-split edit targets a declared range and changes the line"
else
    fail "every post-split edit targets a declared range and changes the line ($bad_edit bad)"
fi

# Two mechanisms writing the same source line would make the result depend on
# which loop runs last. Forbidding the overlap is what lets the reconstruction
# order below be a convention rather than a correctness dependency.
grep -v '^#' "$POST_EDITS" | grep -v '^$' | cut -f1 >"$TEST_ROOT/post-edit-lines"
grep -v '^#' "$REFERENCES" | grep -v '^$' | cut -f1 >"$TEST_ROOT/reference-lines"
both="$(grep -Fxf "$TEST_ROOT/post-edit-lines" "$TEST_ROOT/reference-lines" | tr '\n' ' ')"
if [ -z "$both" ]; then
    pass "no line is edited by both tables"
else
    fail "no line is edited by both tables (shared: ${both% })"
fi

# Same hazard as the references table: awk -v reinterprets backslash escapes in
# the value it is handed, and both the substitution side and this verifier use
# awk -v, so a mangled replacement would look identical on each side and pass
# unnoticed.
# shellcheck disable=SC1003  # the literal backslash is the pattern, not an escape
if grep -v '^#' "$POST_EDITS" | cut -f3 | grep -qF '\'; then
    fail "no post-split replacement contains a backslash (awk -v would reinterpret it)"
else
    pass "no post-split replacement contains a backslash"
fi

# Pinned like check 4's rewrite count, and doubling as the loop's liveness
# guard: `post_edit_count` is incremented inside the loop body, so a loop that
# never ran — a failed redirection, an emptied table — reports 0 here instead of
# leaving the assertion above vacuously clean. Growth of this channel must be a
# deliberate bump, not a silent one.
if [ "$post_edit_count" -eq 8 ]; then
    pass "exactly 8 declared post-split edits"
else
    fail "exactly 8 declared post-split edits (got $post_edit_count)"
fi

# --- 5. Reconstruct each destination from the original plus rewrites. ---
reconstruct() {
    local dest="$1" start="$2" end="$3" out="$4"
    sed -n "${start},${end}p" "$original" >"$out"
    while IFS="$TAB" read -r src _referent disposition replacement; do
        case "$src" in \#* | "") continue ;; esac
        [ "$disposition" = "rewrite" ] || continue
        [ "$src" -ge "$start" ] && [ "$src" -le "$end" ] || continue
        local offset=$((src - start + 1))
        awk -v n="$offset" -v repl="$replacement" \
            'NR==n { print repl; next } { print }' "$out" >"$out.tmp"
        mv "$out.tmp" "$out"
    done <"$REFERENCES"
    # Post-split edits apply after the positional rewrites. Check 4b forbids a
    # source line appearing in both tables, so this ordering is a stated
    # convention rather than a correctness dependency.
    while IFS="$TAB" read -r src _reason replacement; do
        case "$src" in \#* | "") continue ;; esac
        [ "$src" -ge "$start" ] && [ "$src" -le "$end" ] || continue
        local offset=$((src - start + 1))
        awk -v n="$offset" -v repl="$replacement" \
            'NR==n { print repl; next } { print }' "$out" >"$out.tmp"
        mv "$out.tmp" "$out"
    done <"$POST_EDITS"
}

# 5a. Runnable before the split: all reconstructions concatenated in source
#     order must equal the original, modulo untracked blanks and rewrites.
joined="$TEST_ROOT/joined.md"
: >"$joined"
sed -n '1,10p' "$original" >>"$joined"
while IFS="$TAB" read -r dest start end; do
    case "$dest" in \#* | "") continue ;; esac
    reconstruct "$dest" "$start" "$end" "$TEST_ROOT/recon-$dest"
    cat "$TEST_ROOT/recon-$dest" >>"$joined"
done <"$MANIFEST"

baseline="$TEST_ROOT/baseline.md"
cp "$original" "$baseline"
while IFS="$TAB" read -r src _referent disposition replacement; do
    case "$src" in \#* | "") continue ;; esac
    [ "$disposition" = "rewrite" ] || continue
    awk -v n="$src" -v repl="$replacement" \
        'NR==n { print repl; next } { print }' "$baseline" >"$baseline.tmp"
    mv "$baseline.tmp" "$baseline"
done <"$REFERENCES"
# The same post-split edits the reconstructions carry, addressed by raw source
# line number rather than by in-file offset. This must run before the untracked
# blanks are deleted, or every number below the first deletion shifts.
while IFS="$TAB" read -r src _reason replacement; do
    case "$src" in \#* | "") continue ;; esac
    awk -v n="$src" -v repl="$replacement" \
        'NR==n { print repl; next } { print }' "$baseline" >"$baseline.tmp"
    mv "$baseline.tmp" "$baseline"
done <"$POST_EDITS"
# Drop the untracked blank separators, highest line first so earlier
# numbers stay valid. One sed program: "356d;273d".
del="$(printf '%s\n' "${UNTRACKED_BLANKS[@]}" | sort -rn | sed 's/$/d/' | tr '\n' ';')"
sed "$del" "$baseline" >"$baseline.tmp" && mv "$baseline.tmp" "$baseline"

if cmp -s "$joined" "$baseline"; then
    pass "reconstructions concatenate back to the original plus declared edits, byte-for-byte"
else
    fail "reconstructions concatenate back to the original plus declared edits, byte-for-byte"
    diff "$baseline" "$joined" | head -20
fi

# 5b. Runs once the split has happened: each destination file on disk equals
#     its reconstruction. Gated on the index no longer carrying section
#     bodies, so a pre-split run reports SKIP rather than a vacuous pass.
# A skip is legal only in a genuinely untouched pre-split tree: the index
# still carries the section bodies AND not one destination file exists yet.
# Either signal alone is forgeable by a half-finished split, which is
# precisely the state this check must refuse to wave through.
split_started=0
while IFS="$TAB" read -r dest _; do
    case "$dest" in \#* | "") continue ;; esac
    if [ -e "$GATE_DIR/$dest" ]; then
        split_started=1
    fi
done <"$MANIFEST"

if [ "$split_started" -eq 0 ] &&
    grep -Fq '## 1. Preflight availability' "$GATE_DIR/codex-review-gate.md"; then
    skip "per-file byte-identity (pre-split: index still holds section bodies)"
else
    # The index preamble is the one destination with no manifest row, so the
    # loop below would never see it and check 5a compares it against itself
    # (both sides read lines 1-10 from the pinned original). Without this,
    # silently rewording the preamble during the split passes every check.
    if cmp -s <(sed -n '1,10p' "$original") <(sed -n '1,10p' "$GATE_DIR/codex-review-gate.md"); then
        pass "index preamble is byte-identical to source lines 1-10"
    else
        fail "index preamble is byte-identical to source lines 1-10"
        diff <(sed -n '1,10p' "$original") <(sed -n '1,10p' "$GATE_DIR/codex-review-gate.md")
    fi
    while IFS="$TAB" read -r dest start end; do
        case "$dest" in \#* | "") continue ;; esac
        if [ ! -f "$GATE_DIR/$dest" ]; then
            fail "$dest exists"
            continue
        fi
        if cmp -s "$TEST_ROOT/recon-$dest" "$GATE_DIR/$dest"; then
            pass "$dest is byte-identical to source lines $start-$end"
        else
            fail "$dest is byte-identical to source lines $start-$end"
            diff "$TEST_ROOT/recon-$dest" "$GATE_DIR/$dest" | head -10
        fi
    done <"$MANIFEST"
    # Duplication is the failure this file's header names and the contract
    # test cannot catch. Every other check here is blind to it: check 5a
    # compares reconstructions to the original, the per-file loop compares
    # section files to their ranges, and the preamble check reads only the
    # index's first ten lines. So no reconstructed body line may survive
    # anywhere in the index. Whole-line fixed-string matching, one pass.
    #
    # Every non-blank body line is a needle in BOTH its forms: as it reads in
    # the reconstruction, and as it reads in the pinned original. Eight
    # references are rewritten when they move, so a reconstruction-only needle
    # set leaves the seven distinct pre-rewrite strings watched by nothing —
    # source 106, 130, 131, 133, 196, 218 and 229/244 — and an index holding
    # one of them passes clean. Earlier rounds also excluded fence markers and
    # table separator rows as content-free lines a router might legitimately
    # grow; every such exclusion reopened the same hole, so there are none
    # left. Measured against the index states this split produces — Task 3's
    # 23-line index and the 46-line index Task 4 grows it into — the 569-needle
    # union collides with neither. If some later index genuinely needs a line
    # byte-identical to a body line, the answer is to compare the index against
    # its expected contents, not to re-open a class of unwatched lines.
    #
    # Blank and whitespace-only lines stay out: `grep -Fxf` with a blank needle
    # matches every blank line in the index, which would make this a permanent
    # false failure.
    needles_raw="$TEST_ROOT/index-needles-raw"
    needles="$TEST_ROOT/index-needles"
    : >"$needles_raw"
    while IFS="$TAB" read -r dest start end; do
        case "$dest" in \#* | "") continue ;; esac
        grep -v '^[[:space:]]*$' "$TEST_ROOT/recon-$dest" >>"$needles_raw"
        sed -n "${start},${end}p" "$original" |
            grep -v '^[[:space:]]*$' >>"$needles_raw"
    done <"$MANIFEST"
    sort -u "$needles_raw" >"$needles"

    needle_count="$(wc -l <"$needles" | tr -d ' ')"
    if [ "$needle_count" -lt 520 ]; then
        # An empty or truncated needle file makes the grep below vacuously
        # clean, which is exactly the silent pass this check exists to
        # prevent. 569 today; the floor catches a collapse, not drift.
        fail "needle set is populated (expected ~569 body lines, got $needle_count)"
    elif grep -Fxf "$needles" "$GATE_DIR/codex-review-gate.md" >"$TEST_ROOT/dupes"; then
        fail "index carries $(wc -l <"$TEST_ROOT/dupes" | tr -d ' ') line(s) that also appear in a section body"
        head -5 "$TEST_ROOT/dupes" | sed 's/^/    /'
    fi
fi

# --- 6. Audit trail for the two contract needles the rewrites touch. ---
# Two of the 119 assertions in test-gate-contract.sh pin text that the
# declared rewrites change, so Task 3 edits those two needles. This check is
# what makes that edit auditable: both retired strings must be absent and
# both replacements present in the reconstruction, which is derived from the
# pinned original plus the declared replacements and nothing else. Check 5
# already proves no other line moved. Together they mean a quiet rewording
# cannot hide behind "an intentional test edit".
#
# Matching uses the same normalization as the contract test, because the
# needles span line breaks in the source.
normalized="$TEST_ROOT/joined.normalized"
tr '\n\t' '  ' <"$joined" | sed 's/  */ /g' >"$normalized"

RETIRED_1="Copy the Required document-review output block below into the prompt"
RETIRED_2="composes the per-lens prompts from the lens fan-out block below"
REPLACEMENT_1="Copy the Required document-review output block from gate-output-schema.md into the prompt"
REPLACEMENT_2="composes the per-lens prompts from the lens fan-out block in gate-lenses.md"

for needle in "$RETIRED_1" "$RETIRED_2"; do
    if grep -Fq "$needle" "$normalized"; then
        fail "retired contract needle is gone: \"$needle\""
    else
        pass "retired contract needle is gone: \"$needle\""
    fi
done
for needle in "$REPLACEMENT_1" "$REPLACEMENT_2"; do
    if grep -Fq "$needle" "$normalized"; then
        pass "replacement contract needle is present: \"$needle\""
    else
        fail "replacement contract needle is present: \"$needle\""
    fi
done

# The suite has exactly two legal shapes. Anything else means a check
# vanished, or the tree is in a half-split state that no single assertion
# above would catch. Without this, a check could stop running and its
# silence would read as success. This assertion prints nothing when it
# holds, so the two documented counts stay exact.
if ! { { [ "$skips" -eq 1 ] && [ "$passes" -eq 16 ]; } ||
    { [ "$skips" -eq 0 ] && [ "$passes" -eq 26 ]; }; }; then
    fail "check inventory is one of the two legal shapes (pre-split 16 PASS/1 SKIP, post-split 26 PASS/0 SKIP); got $passes PASS/$skips SKIP"
fi

echo ""
if [ "$failures" -gt 0 ]; then
    echo "STATUS: FAILED ($failures failures)"
    exit 1
fi
echo "STATUS: PASSED"
