# Sweep Open Findings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. A correction added during execution that alters one of the spec's decisions names it: `Correction (<date>), decision <N> (<title>):`.

**Spec:** docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md

**Goal:** Fix every finding the spec restates from the 2026-11-07 review sweep that is still present at e62fdb5: the final-train takeover after a killed finish and a damaged `closing=`; amend's lost swap, missing worktree directories and refresh deletion; record publishing, the plain snapshot, session ids and the board; replace objects, grafts, symbolic refs and the seven-character approval line; the single findings in `deps`, `register`, `claim`, the plan parser, `enc` and one fixture; the skill text that contradicts the scripts; and the stop guard's completion pattern. Each behavior change has a test that fails at e62fdb5.

**Architecture:** Every fix stays inside the code that has the defect: `sdd-state` subcommands and helpers, `sdd-common.sh` (the plan parser and a new shared completion pattern), `review-package`, and `hooks/lib/stop-guard.mjs`. No new subcommand, status or exit code; the only new outputs are the stderr lines the spec quotes, and the one line this plan writes where the spec names a case without quoting it (E6-b's both-paths line, in Task 2). Test seams follow the existing `HYPERPOWERS_TEST_WRITER_AT`, `HYPERPOWERS_TEST_CRASH_AT` and `HYPERPOWERS_TEST_PAUSE_AT` shapes, and every seam this work adds also touches the file named by `HYPERPOWERS_TEST_SEAM_MARK` when it fires, so a test can prove its seam ran. Skill-text edits ride with the code they describe (Task 4) or come last (Task 6), each pinned by contract needles.

**Tech Stack:** bash (3.2-compatible; `set -uo pipefail` in `sdd-state`), node (the atomic rename and the stop guard), git 2.38 for `amend` and `merge-back`; tests are the existing bash suites and `node --test`; the scratch helpers below use python3 and bash and live outside the repository.

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`, `docs/testing.md`
- Notation. `<worktree>` is the absolute path of the branch worktree that using-git-worktrees creates at execution time; `<sw>` is `/Users/johnss51/.cache/hyperpowers/sweep-open-findings`. The controller substitutes both literally into every command before it runs it, never through a shell variable, so sandbox exclusions can match.
- Red runs. Every finding that changes behavior has at least one assertion that fails at e62fdb5 because of the defect, run before its fix. A red run uses a `git archive e62fdb5` copy under `<sw>/red/` made by `<sw>/make-red.sh` (it copies the branch's test files in), never `git stash`. A test that drives a seam this work adds runs red against that copy with only the seam's lines applied (the same lines the fix keeps) and asserts the seam's marker file. Exempt, with their reasons: positive controls (`### Tasks overview` and `### Task-runner notes` still parse; the plain refresh still writes the new plan; the guards of E6-b (d), (e) and the link variant, which already refuse at e62fdb5 because `read-tree -m -u` refuses a mode or type change; the newline-target link guard, which passes at e62fdb5 because `read-tree -m -u` compares the link itself). A merge with a full-id approval line is not exempt: it fails at e62fdb5, which reads only a seven-character token, and test-only changes (the E12 conflict-route fixture; the E3-f seam's own test, whose subject is the new seam). Each task report names its exempt tests and the reason.
- Never run the full state suite (`tests/sdd/test-sdd-state.sh`) inside the Bash sandbox: it hangs there. Run named slices with `<sw>/run-slices.sh`. The full suite runs once, unsandboxed, in the controller's final step.
- Suites write to log files under `<sw>/logs/`, never into a pipe; read the log afterwards.
- No new heredocs or here-strings in `sdd-state`, `sdd-common.sh`, `hooks/` or `tests/`: write fixtures with `printf`.
- Existing statuses and exit codes are reused. Every path-valued status field goes through `enc`.
- Docs digests. A commit that changes a source a `docs/site/` page lists re-reads that page, fixes stale text, and refreshes its `source-digest:` with `bash <sw>/refresh-digests.sh <worktree>`, which recomputes every page whose digest went stale and prints each page it changed; `bash <worktree>/tests/docs/docs-check.sh --root <worktree>` must then exit 0.
- CHANGELOG. One sentence per fix, in the existing `## Unreleased` bullets, in the commit that makes the fix, through `<sw>/changelog-append.py`. No sentence for E3-f, E12 or the evidence note (test-only or not a fix).
- Skill text. Only the sentences spec sections 4 and 6 name change; the Red Flags tables, rationalization lists and "your human partner" language are untouched. using-git-worktrees does not change.
- Commits. One finding per commit, conventional prefix, the message given in its step, no Co-Authored-By line, no AI-attribution line, no dollar figures anywhere. Stage by named path. Before each commit: `git -C <worktree> diff --cached > <sw>/logs/<id>.staged.diff`, then `python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/<id>.staged.diff`, expecting `hits: 0`.
- Lint. `bash <worktree>/scripts/lint-shell.sh <files>` exits 0 for every changed script except `tests/sdd/test-sdd-state.sh`, which keeps its baseline: exit 1 with exactly five `SC1090` findings and no other code (checked from the log, below).
- No live suites and no live eval runs. The offline set from `docs/testing.md` runs once at the end, unsandboxed, by the controller.
- Comments explain why, in complete sentences; stderr lines carry the `sdd-state:` prefix.

## Grounding

- `skills/subagent-driven-development/scripts/sdd-state:122-126`: `enc`, a space to `%20` only; Task 5 replaces it.
- `sdd-state:200-212`: `sid_ok`, the session-id rule and its stderr line; Task 3 widens it. Callers at `:226` (`record_publish`), `:435` (`snapshot`), `:520` (`claim`), `:2117` (`amend`), `:2411` (`merge-back`), `:2637` (`wait`); `register` (`:321-332`) has none.
- `sdd-state:213-233`: `record_publish`, the pre-check and `mv -f`; `:877` the node `renameSync` one-liner claim uses, which Task 3 mirrors.
- `sdd-state:273-313`: `cmd_deps`, `--from` hashed at `:296` and parsed again from the caller's file at `:301-308`; `:246-250` `authoritative_plan_blob`'s private copy, whose `mktemp` template Task 5 mirrors.
- `sdd-state:321-420`: `cmd_register`; `:349` records `code_root=$(root_of "$code")`; `:4080-4082` `root_of`.
- `sdd-state:423-456`: `cmd_snapshot`; `:435` the empty-id skip, `:441` the unlocked plain stamp, `:446-453` the branch path's locked stamp.
- `sdd-state:482-494`: `ledger_marks_complete`, the completion ERE Task 6 moves into `sdd-common.sh`.
- `sdd-state:502-549`: `cmd_claim` and `claim_take_locks`, `code_repo_arg` only with a plan line or `--code-repo`.
- `sdd-state:700-735`: `claim_final`'s takeover; `:724` `[ "$lclosing" = 1 ] || lclosing=0`. `:751-774`: `claim_final_orphan`, the same at `:769`. `:775-790`: the loop that settles the plan line and the locks, then the no-ledger branch that calls `claim_final_orphan`.
- `sdd-state:855-884`: the numbered takeover's owner rename (`:863-864`) with no seam, and the fresh path's `claim-after-rename` seam (`:880`).
- `sdd-state:1571-1592`: `restore_tomb`; `:1627` the `remove-after-rename` crash seam; `:1805-1834`: `cmd_finish`'s lock and its copy-restore loop.
- `sdd-state:2090-2296`: `cmd_amend`; `:2128` the blob, `:2191-2194` the crash-window refresh, `:2222-2272` the attempt loop (`:2246` the blocker in a command substitution, `:2256` the `amend-before-swap` seam, `:2257` the swap, `:2265-2271` the lost-swap retry).
- `sdd-state:2297-2374`: `amend_ref_worktrees` (skips a missing directory at `:2309`), `amend_wt_index`, `amend_wt_blocker`, `amend_wt_plan_clean`, `amend_refresh` (`:2365-2369` check then `read-tree -m -u`).
- `sdd-state:2387-2541`: `cmd_merge_back`; `:2393` `GIT_NO_REPLACE_OBJECTS`, `:2437-2454` the seven-character approval and `--disambiguate`, `:2491` the attempt loop, `:2510` the conflict path's waiting record, `:2525` the `merge-back-before-swap` seam, `:2526` the swap.
- `sdd-state:2610-2671`: `merge_back_wait` and `cmd_wait` (`:2663-2664` record then stamp).
- `sdd-state:2674-2685`: `board_entries`, names printed unvalidated.
- `skills/subagent-driven-development/scripts/sdd-common.sh:152-169`: `hp_ledger_records`; `:262-280` `hp_plan_graph`'s awk, `:278` the multi-level heading rule; `:463-467` `hp_lock` (the lock directory is `hp_checkout_path` plus `.lock`, the plain backend included).
- `skills/subagent-driven-development/scripts/review-package:15-17` (`set -euo pipefail`, `SCRIPT_DIR`) and `:56-67` (the package: `git log --oneline`, `--stat`, `diff -U10`).
- `hooks/lib/stop-guard.mjs:15` (`COMPLETE`) and `:180` (its one use).
- `hooks/lib/stop-guard.test.mjs:28-33` (the `ledger` helper) and `:87-93` (the prose-mention test).
- `tests/hooks/test-sdd-stop-guard.sh:1-15` (header, `LIB`, `pass`/`fail`) and `:187-192` (the bash/node key parity, the shape the completion parity mirrors).
- `tests/sdd/test-sdd-state.sh:1-80`: the harness (`make_repo`, `make_pair`, `ensure`, `state_key`, `run_state`, `run_sdd_dir`, `ws_path`, `mkreg`, `STATE_ROOT`, `TEST_ROOT`, `LIB`, `SDD_STATE`). Anchors used below: `:580` (plain snapshot), `:3140` (`dep_bad twice`), `:3440` (lock pair), `:3509-3511` (takeover fork test), `:3521` (claim without a plan line), `:3648-3654` (owner retry), `:4047-4067` (the `ft` fixture, the model for `fk` and `dc`), `:4068` (plan= encoding), `:4240-4248` (amend lost swap), `:4446` (merge-back section), `:4527-4529` (merge-back conflict), `:4606-4628` (approval-token tests), `:4631-4632` (the `racegit` wrapper), `:4660` (session id at merge-back's entry), `:4833` (closing STATUS line).
- `tests/claude-code/test-sdd-dir-path.sh:40-45` (`make_repo`, no commit) and `:537-567` (the review-package range tests, `|| rc=$?` under `set -euo pipefail`).
- `tests/sdd/test-sdd-contract.sh:21-60` (`assert_contains`, `assert_not_contains`, `assert_before`, whitespace-normalized), `:180` (`SDD_EXAMPLE_WORKFLOW`), `:470-472` (claim resume and the approval needles), `:479` (BASE), `:513-514` (finishing), `:636` (last assertion).
- `skills/subagent-driven-development/SKILL.md:133-139` (Setup), `:415-421` (BASE), `:489-491` (claim `error`), `:790-796` (approval), `:806` (`not-approved` keeps its form); `example-workflow.md:40`, `:78`.
- `skills/finishing-a-development-branch/SKILL.md:103-104` (Step 1 item 5), `:274-277` (withheld merge); `skills/finishing-a-development-branch/scripts/decisions-compile:882`, `:887`, `:905`, `:909` (the three refusals).
- `docs/site/advanced/sdd-internals.md:43`, `:59`, `:61`, `:72`; `docs/site/skills/subagent-driven-development.md:27`; `docs/site/skills/finishing-a-development-branch.md:27`, `:33`; `docs/testing.md:23`.
- `CHANGELOG.md` `## Unreleased`: one line per bullet; the prefixes used are `- **Several sessions can work one plan, or sibling plans of one spec, at once.**`, `- **Smaller fixes to the multi-session helpers.**` (ends `no longer reads as done.`) and `- **A second plan of one spec recompiles its records.**`.
- `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md:1-10`: the evidence-note header the reachability note mirrors.
- Probes behind this plan (2026-11-09, git 2.56, bash 3.2.57 and 5): `hash-object --path=<abs> -- <copy>` gives the id `hash-object <abs>` gives; `update-ref --no-deref` on a symbolic ref makes it a regular ref and leaves its target; a `git worktree lock`ed worktree moved away stays listed and locked, `prune` keeps it, `unlock` then `prune` removes it; `read-tree -m -u` refuses a mode or type change; worktree paths with a newline add and remove; the new `enc` prints `/a%20b%0Ac%09d%20e%7F` and keeps UTF-8 bytes and a literal `%20`; at e62fdb5 a finish killed at `remove-after-rename` leaves `.removing-plan-<hash>-<pid>` and the orphan takeover answers `status=claimed task=final lease=<name> takeover=1` with the copy left; `register` with the code checkout on an unrelated root records that root, `verify` answers `ok` and `next` answers `wrong-repo`; register, claim and merge-back work in a `--object-format=sha256` repository; no host ledger holds a session line with whitespace or a colon in its id (4 lines, 0 bad).
- none: no existing helper restores a removal copy outside `cmd_finish` (Task 1 extracts `restore_removed_copy`); none: no existing shared completion pattern between bash and node (Task 6 adds `hp_complete_ere` and `completePattern`).

## Scratch helpers

The controller writes these files once, before Task 1, with the Write tool (no heredocs), and makes the directories `<sw>/logs`, `<sw>/snippets` and `<sw>/red`. They live outside the repository and are never committed. Every task calls them by literal path. Snippet files the steps name are written with the Write tool to `<sw>/snippets/` with exactly the content shown.

`<sw>/run-slices.sh`:

```bash
#!/usr/bin/env bash
# Runs named slices of TREE/tests/sdd/test-sdd-state.sh against TREE's own
# scripts: the branch worktree for green runs, a red tree for red runs. The
# helper header is kept with REPO_ROOT pinned to TREE, and each slice is cut
# by its markers, so line shifts from edits do not move the cut. No slice
# holds the final section's cross-repository release fixture, which hangs
# inside the Bash sandbox. plainfix goes before snapshot. amend already holds
# amendwt, claim2 holds ownerretry, and final-head holds finalrepeat, so
# those pairs are never listed together.
# usage: run-slices.sh TREE SLICE...
set -u
[ $# -ge 2 ] || { echo "usage: run-slices.sh TREE SLICE..." >&2; exit 2; }
TREE=$(cd "$1" && pwd -P) || exit 2
shift
SUITE="$TREE/tests/sdd/test-sdd-state.sh"
LOGS=/Users/johnss51/.cache/hyperpowers/sweep-open-findings/logs
mkdir -p "$LOGS" || exit 2
out=$(mktemp "$LOGS/slices.XXXXXX") || exit 2
ln_of() { grep -nF -- "$1" "$SUITE" | head -n 1 | cut -d: -f1; }
range() { # <start marker> <end marker, exclusive>
  local s e
  s=$(ln_of "$1"); e=$(ln_of "$2")
  [ -n "$s" ] && [ -n "$e" ] || { echo "marker not found: $1 / $2" >&2; exit 2; }
  sed -n "${s},$((e - 1))p" "$SUITE"
}
hdr_end=$(( $(ln_of 'echo "=== creation ==="') - 1 ))
{
  sed -n "1,${hdr_end}p" "$SUITE" | sed "s|^REPO_ROOT=.*|REPO_ROOT=\"$TREE\"|"
  for s in "$@"; do
    case "$s" in
      plainfix) range '# A repository kept on the plain backend' '# A checkout left on another branch' ;;
      snapshot) range 'echo "=== snapshot ==="' 'echo "=== claim ==="' ;;
      claim) range 'echo "=== claim ==="' 'echo "=== import ==="' ;;
      import) range 'echo "=== import ==="' 'echo "=== sdd-dir and the plain fallback' ;;
      finish) range 'echo "=== finish ==="' 'echo "=== prune ==="' ;;
      sync) range 'echo "=== sync ==="' 'echo "=== verify ==="' ;;
      handoff) range 'echo "=== handoff ==="' 'echo "=== leftover entries under plans/ ==="' ;;
      complete) range '# --- complete and handback' '# --- a job' ;;
      deps) range 'echo "deps: the plan graph' 'echo "register: the plan line' ;;
      register) range 'echo "register: the plan line' 'echo "claim: dependencies and branches"' ;;
      claim2) range 'echo "claim: dependencies and branches"' 'echo "next: the claimable frontier"' ;;
      ownerretry) range "# The owner's retry is a successful claim too" '# The branch line goes through hp_ledger_append' ;;
      next) range 'echo "next: the claimable frontier"' 'echo "final: claim, lease, finish"' ;;
      final-head) range 'echo "final: claim, lease, finish"' 'pass "the lease still blocks the sibling after finish"' ;;
      finalrepeat) range "# The holder's repeat of claim final clears the record too" "printf 'time=2026-01-01T00:00:00Z" ;;
      finaltail) range '# A holder that dies after finish and before releasing the lease' '# Workspace names in the plan= field are encoded' ;;
      amend) range 'echo "amend: the plan ref' 'echo "merge-back: the integration ref' ;;
      amendwt) range '# Amend and the worktrees on the plan ref' 'echo "merge-back: the integration ref' ;;
      mergeback) range 'echo "merge-back: the integration ref' 'echo "board: waiting records' ;;
      board) range 'echo "board: waiting records' 'if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED' ;;
      *) echo "unknown slice: $s" >&2; exit 2 ;;
    esac
  done
  printf '\nif [ "$failures" -gt 0 ]; then echo "STATUS: FAILED ($failures failures)"; exit 1; fi\necho "STATUS: PASSED"\n'
} > "$out"
echo "slices: $* (tree $TREE)"
timeout 1200 bash "$out"; rc=$?
rm -f "$out"
exit "$rc"
```

`<sw>/make-red.sh`:

```bash
#!/usr/bin/env bash
# Builds <sw>/red/NAME: the tree at e62fdb5, from git archive, with the
# branch worktree's test files copied in. Seam lines, when a test needs them,
# are applied afterwards with insert-at.py, and nothing else is changed.
# usage: make-red.sh BRANCH_TREE NAME
set -u
[ $# -eq 2 ] || { echo "usage: make-red.sh BRANCH_TREE NAME" >&2; exit 2; }
src=$(cd "$1" && pwd -P) || exit 2
RED=/Users/johnss51/.cache/hyperpowers/sweep-open-findings/red
dest="$RED/$2"
[ ! -e "$dest" ] || { echo "red tree exists: $dest" >&2; exit 2; }
mkdir -p "$dest" || exit 2
git -C "$src" archive --format=tar e62fdb5 > "$RED/$2.tar" || exit 2
tar -xf "$RED/$2.tar" -C "$dest" || exit 2
rm -f "$RED/$2.tar"
for f in tests/sdd/test-sdd-state.sh tests/sdd/test-sdd-contract.sh tests/hooks/test-sdd-stop-guard.sh hooks/lib/stop-guard.test.mjs tests/claude-code/test-sdd-dir-path.sh; do
  cp "$src/$f" "$dest/$f" || exit 2
done
echo "$dest"
```

`<sw>/insert-at.py`:

```python
#!/usr/bin/env python3
"""Insert a snippet before or after the one line containing NEEDLE, or replace it.

usage: insert-at.py FILE before|after|replace NEEDLE SNIPPET_FILE
Exits 1 unless exactly one line of FILE contains NEEDLE.
"""
import sys


def main() -> int:
    if len(sys.argv) != 5 or sys.argv[2] not in ("before", "after", "replace"):
        print(__doc__, file=sys.stderr)
        return 2
    path, where, needle, snip = sys.argv[1:]
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        lines = f.read().splitlines(keepends=True)
    with open(snip, encoding="utf-8", errors="surrogateescape", newline="") as f:
        text = f.read()
    if not text.endswith("\n"):
        text += "\n"
    hits = [i for i, line in enumerate(lines) if needle in line]
    if len(hits) != 1:
        print(f"insert-at: {len(hits)} lines contain the needle in {path}", file=sys.stderr)
        return 1
    i = hits[0]
    if where == "before":
        lines[i:i] = [text]
    elif where == "after":
        if not lines[i].endswith("\n"):
            lines[i] += "\n"
        lines[i + 1:i + 1] = [text]
    else:
        lines[i:i + 1] = [text]
    with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write("".join(lines))
    print(f"{where} line {i + 1} of {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`<sw>/replace-range.py`:

```python
#!/usr/bin/env python3
"""Replace a range of lines with a snippet.

usage: replace-range.py FILE START END SNIPPET_FILE
The range runs from the one line containing START through the first line at
or after it containing END, both included. Exits 1 unless exactly one line
contains START and a line at or after it contains END.
"""
import sys


def main() -> int:
    if len(sys.argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    path, start, end, snip = sys.argv[1:]
    with open(path, encoding="utf-8", errors="surrogateescape", newline="") as f:
        lines = f.read().splitlines(keepends=True)
    with open(snip, encoding="utf-8", errors="surrogateescape", newline="") as f:
        text = f.read()
    if not text.endswith("\n"):
        text += "\n"
    hits = [i for i, line in enumerate(lines) if start in line]
    if len(hits) != 1:
        print(f"replace-range: {len(hits)} lines contain the start needle in {path}", file=sys.stderr)
        return 1
    s = hits[0]
    e = next((i for i in range(s, len(lines)) if end in lines[i]), None)
    if e is None:
        print(f"replace-range: no line from the start on contains the end needle in {path}", file=sys.stderr)
        return 1
    lines[s:e + 1] = [text]
    with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.write("".join(lines))
    print(f"replaced lines {s + 1}-{e + 1} of {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`<sw>/changelog-append.py`:

```python
#!/usr/bin/env python3
"""Add a sentence to the one Unreleased bullet that starts with PREFIX.

usage: changelog-append.py FILE PREFIX SENTENCE [AFTER]
Each bullet is one line. With AFTER, the sentence goes right after the first
occurrence of AFTER in that bullet; otherwise at the bullet's end. Only the
"## Unreleased" section is searched. Exits 1 unless exactly one bullet there
starts with PREFIX, AFTER (when given) occurs in it, and the sentence is not
already present.
"""
import sys


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print(__doc__, file=sys.stderr)
        return 2
    path, prefix, sentence = sys.argv[1:4]
    after = sys.argv[4] if len(sys.argv) == 5 else None
    with open(path, encoding="utf-8", newline="") as f:
        lines = f.read().splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.rstrip("\r\n") == "## Unreleased"), None)
    if start is None:
        print("changelog-append: no ## Unreleased section", file=sys.stderr)
        return 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    hits = [i for i in range(start + 1, end) if lines[i].startswith(prefix)]
    if len(hits) != 1:
        print(f"changelog-append: {len(hits)} Unreleased bullets start with the prefix", file=sys.stderr)
        return 1
    i = hits[0]
    body = lines[i].rstrip("\r\n")
    eol = lines[i][len(body):]
    if sentence in body:
        print("changelog-append: the sentence is already in the bullet", file=sys.stderr)
        return 1
    if after is None:
        body = body + " " + sentence
    else:
        k = body.find(after)
        if k < 0:
            print("changelog-append: AFTER does not occur in the bullet", file=sys.stderr)
            return 1
        k += len(after)
        body = body[:k] + " " + sentence + body[k:]
    lines[i] = body + eol
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write("".join(lines))
    print(f"changelog: line {i + 1}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

`<sw>/refresh-digests.sh`:

```bash
#!/usr/bin/env bash
# Recomputes the source-digest: line of each tracked docs/site page in TREE
# whose digest is stale (or of the named pages only), and prints each page it
# changed, so the caller re-reads exactly those.
# usage: refresh-digests.sh TREE [PAGE...]   (PAGE relative to TREE)
set -u
[ $# -ge 1 ] || { echo "usage: refresh-digests.sh TREE [PAGE...]" >&2; exit 2; }
tree=$(cd "$1" && pwd -P) || exit 2
shift
list=$(mktemp "${TMPDIR:-/tmp}/digest-pages.XXXXXX") || exit 2
if [ $# -eq 0 ]; then git -C "$tree" ls-files -- 'docs/site/*.md' > "$list"; else printf '%s\n' "$@" > "$list"; fi
rc=0
while IFS= read -r page; do
  [ -n "$page" ] || continue
  grep -q '^source-digest:' "$tree/$page" || continue
  new=$(bash "$tree/tests/docs/docs-check.sh" --root "$tree" --digest "$page") || { echo "digest failed: $page" >&2; rc=1; continue; }
  old=$(sed -n 's/^source-digest: //p' "$tree/$page" | head -n 1)
  [ "$new" != "$old" ] || continue
  awk -v d="$new" '!done && /^source-digest:/ { print "source-digest: " d; done = 1; next } { print }' "$tree/$page" > "$tree/$page.tmp" && mv "$tree/$page.tmp" "$tree/$page"
  echo "refreshed $page"
done < "$list"
rm -f "$list"
exit "$rc"
```

`<sw>/sid-check.sh`:

```bash
#!/usr/bin/env bash
# Lists the session lines of every ledger on this host and counts those whose
# id holds whitespace or a colon, which the widened sid_ok would refuse.
set -u
D=/Users/johnss51/.cache/hyperpowers/sweep-open-findings
mkdir -p "$D/logs" || exit 2
out="$D/logs/sid-lines.txt"
: > "$out"
for f in /Users/johnss51/.cache/hyperpowers/state/*/plans/*/progress.md /Users/johnss51/.cache/hyperpowers/sdd/*/plans/*/progress.md; do
  [ -f "$f" ] || continue
  grep -E '^session ' "$f" >> "$out"
done
lines=$(grep -c . "$out")
bad=$(grep -vcE '^session [^[:space:]:]+: (mode|tasks) ' "$out")
echo "lines=$lines bad=$bad"
```

Each task ends with the same verification block, with its own log prefix `tN` and its own changed-file list. A task brief does not carry this section, so the controller also writes the block and the Expected paragraph after it, verbatim, to `<sw>/verification-block.md`, and each task's last step names that file:

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/tN-contract.log 2>&1
bash <worktree>/tests/hooks/test-sdd-stop-guard.sh > <sw>/logs/tN-stopguard.log 2>&1
bash <worktree>/tests/hooks/test-no-heredocs-in-hooks.sh > <sw>/logs/tN-heredocs.log 2>&1
bash <worktree>/tests/docs/docs-check.sh --root <worktree> > <sw>/logs/tN-docs.log 2>&1
bash <worktree>/tests/shell-lint/test-lint-shell.sh > <sw>/logs/tN-lintsuite.log 2>&1
bash <worktree>/scripts/lint-shell.sh <worktree>/tests/sdd/test-sdd-state.sh > <sw>/logs/tN-lint-state.log 2>&1
grep -o 'SC[0-9]*' <sw>/logs/tN-lint-state.log > <sw>/logs/tN-lint-state.codes
sort <sw>/logs/tN-lint-state.codes | uniq -c
```

Expected: each of the first five commands exits 0 (`echo $?` after each; the suites' logs end in `STATUS: PASSED`); the lint of the state suite exits 1 and the last command prints one line, the count `5` and `SC1090`. The task's other changed scripts go through `bash -n <file>` and `bash <worktree>/scripts/lint-shell.sh <files> > <sw>/logs/tN-lint.log 2>&1`, exit 0.

---

### Task 1: Final train

**Risk tier:** high — the final-train takeover moves the branch lease and restores a removed workspace under the plan lock: concurrency code and a durable-record writer.

**Depends on:** none

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Test: `tests/sdd/test-sdd-state.sh`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`

**Interfaces:**
- Consumes: `restore_tomb <dir> <tomb>` (`sdd-state:1577`), `claim_take_locks`, `recover_apply`, `claim_final`, `claim_final_orphan`, the crash seam `HYPERPOWERS_TEST_CRASH_AT=remove-after-rename` (`sdd-state:1627`).
- Produces: `restore_removed_copy` in `sdd-state`, right after `restore_tomb`: reads `WSDIR`; returns 0 when it restored the copy or found none, 3 when a workspace stands at the path (the copy named on stderr with finish's line), 2 when the restore failed. Its callers, `cmd_finish` and a final-train takeover in `cmd_claim`, hold the plan lock.

**Mirror:** `tests/sdd/test-sdd-state.sh:4047-4067` (the `ft` fixture: a one-task plan on `feat`, registered, completed, claimed final) for both tests; `sdd-state:1827-1834` (finish's copy loop) for the restore.

**Finding E5-a, a takeover after a killed finish.**

- [ ] **Step 1: Write the E5-a test**

Write `<sw>/snippets/t1-e5a-test.sh`:

```bash
# A finish killed after its rename-aside leaves the plan's workspace at plans/.removing-<ws>-<pid>, which the other readers count as an open plan. A final-train takeover puts it back first and takes the plan over as an open one; beside a new workspace it names the copy and answers busy, the lease unmoved.
fk="$TEST_ROOT/fk"; make_repo "$fk"; git -C "$fk" switch -q -c feat
mkdir -p "$fk/docs"; : > "$fk/docs/spec.md"; printf '# T\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fk/docs/plan.md"; git -C "$fk" add docs; git -C "$fk" commit -qm plan
wsfk=$(run_sdd_dir "$fk" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsfk/progress.md"
run_state "$fk" register docs/plan.md --session s1 --integration feat >/dev/null
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsfk/progress.md"
run_state "$fk" claim docs/plan.md final --session s1 >/dev/null
lease_fk=""; for fk_f in "$STATE_ROOT/$(state_key "$fk").final-"*; do [ -f "$fk_f" ] && lease_fk=$fk_f; done
( cd "$fk" && HYPERPOWERS_TEST_CRASH_AT=remove-after-rename bash "$SDD_STATE" finish docs/plan.md --session s1 >/dev/null 2>&1 ); rcf=$?
tomb_fk=""; for fk_f in "$(dirname "$wsfk")/.removing-$(basename "$wsfk")-"*; do [ -d "$fk_f" ] && tomb_fk=$fk_f; done
out=$(run_state "$fk" claim docs/plan.md final --session s2 --takeover 2>/dev/null); rc=$?
if [ "$rcf" -eq 99 ] && [ -n "$tomb_fk" ] && [ -n "$lease_fk" ] && [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=final lease=$(basename "$lease_fk") takeover=1" ] && [ -f "$wsfk/progress.md" ] && [ ! -e "$tomb_fk" ] && [ "$(sed -n 's/^session=//p' "$wsfk/claims/final/owner" 2>/dev/null)" = s2 ] && [ "$(sed -n 's/^session=//p' "$lease_fk")" = s2 ]; then pass "a final-train takeover after a finish killed past its rename-aside puts the plan back and takes it over"; else fail "a final-train takeover after a finish killed past its rename-aside puts the plan back and takes it over (finish rc=$rcf tomb=$tomb_fk rc=$rc: $out)"; fi
fk_t2="$(dirname "$wsfk")/.removing-$(basename "$wsfk")-4343"
mv "$wsfk" "$fk_t2"; mkdir "$wsfk"
out=$(run_state "$fk" claim docs/plan.md final --session s3 --takeover 2>"$TEST_ROOT/fk.busy.err"); rc=$?
if [ "$rc" -eq 3 ] && [ "$out" = "status=busy" ] && grep -qF "a copy from an interrupted removal remains at $fk_t2" "$TEST_ROOT/fk.busy.err" && [ -d "$fk_t2" ] && [ "$(sed -n 's/^session=//p' "$lease_fk")" = s2 ]; then pass "beside a new workspace the killed finish's copy is named and the takeover is busy, the lease unmoved"; else fail "beside a new workspace the killed finish's copy is named and the takeover is busy, the lease unmoved (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/fk.busy.err"))"; fi
rmdir "$wsfk"; mv "$fk_t2" "$wsfk"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before '# Workspace names in the plan= field are encoded' <sw>/snippets/t1-e5a-test.sh`
Expected: `before line 4068 of ...` (exit 0).

- [ ] **Step 2: Run E5-a red**

```bash
bash <sw>/make-red.sh <worktree> t1-e5a
bash <sw>/run-slices.sh <sw>/red/t1-e5a finaltail > <sw>/logs/t1-e5a.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t1-e5a.red.log > <sw>/logs/t1-e5a.red.fails
```

Expected: the slice exits 1, and `t1-e5a.red.fails` holds exactly the two new labels, "a final-train takeover after a finish killed past its rename-aside puts the plan back and takes it over" (at e62fdb5 the orphan path prints the same status line but leaves the copy and no ledger) and "beside a new workspace the killed finish's copy is named and the takeover is busy, the lease unmoved" (at e62fdb5 the orphan path moves the lease to s3). The `ft` labels pass.

- [ ] **Step 3: Implement E5-a**

In `sdd-state`, with the Edit tool, three edits.

(a) Replace

```text
# <tomb>: delete a verified copy. A copy that survives the deletion is named;
```

with

```text
# Puts back a copy an interrupted removal left at plans/.removing-<ws>-<pid>
# for this workspace (WSDIR). 0 when it was restored or there was none; 3
# when a workspace stands at the path, the copy named on stderr for a human
# to merge or delete; 2 when the restore failed. finish and a final-train
# takeover run it under the plan lock, the lock finish removes under.
restore_removed_copy() {
  local t
  for t in "$(dirname "$WSDIR")/.removing-$(basename "$WSDIR")-"*; do
    [ -d "$t" ] || continue
    if [ -d "$WSDIR" ]; then
      echo "sdd-state: a copy from an interrupted removal remains at $t; move its files back into $WSDIR or delete it" >&2
      return 3
    fi
    restore_tomb "$WSDIR" "$t" || return 2
  done
  return 0
}
# <tomb>: delete a verified copy. A copy that survives the deletion is named;
```

(b) In `cmd_finish`, replace the locals line

```text
  local plan="" force=0 sid="" code="" open live last commit rc t owner out line c lease lowner lplan
```

with

```text
  local plan="" force=0 sid="" code="" open live last commit rc owner out line c lease lowner lplan
```

and replace the loop under the kept comment ("A removal interrupted after its rename-aside ...")

```text
  for t in "$(dirname "$WSDIR")/.removing-$(basename "$WSDIR")-"*; do
    [ -d "$t" ] || continue
    if [ -d "$WSDIR" ]; then
      echo "sdd-state: a copy from an interrupted removal remains at $t; move its files back into $WSDIR or delete it" >&2
      hp_unlock; echo "status=busy"; return 3
    fi
    restore_tomb "$WSDIR" "$t" || { hp_unlock; echo "status=error"; return 2; }
  done
```

with

```text
  restore_removed_copy; rc=$?
  if [ "$rc" -eq 3 ]; then hp_unlock; echo "status=busy"; return 3; fi
  [ "$rc" -eq 0 ] || { hp_unlock; echo "status=error"; return 2; }
```

(c) In `cmd_claim`'s settle loop, replace

```text
    recover_apply || { hp_unlock; echo "status=error"; return 2; }
    again=$(plan_line_of "$WSDIR/progress.md")
```

with

```text
    recover_apply || { hp_unlock; echo "status=error"; return 2; }
    # A finish killed after its rename-aside left this plan's workspace at
    # plans/.removing-<ws>-<pid>, which the other readers count as an open
    # plan. A final-train takeover puts it back first, under the plan lock as
    # finish does, so the plan line read next is the restored one: the loop
    # settles again with it, and the takeover runs as one of an open plan.
    # Beside a new workspace the copy is named and the claim is busy.
    if [ "$n" = final ] && [ "$takeover" -eq 1 ] && [ ! -f "$WSDIR/progress.md" ]; then
      restore_removed_copy; rc=$?
      if [ "$rc" -eq 3 ]; then hp_unlock; echo "status=busy"; return 3; fi
      [ "$rc" -eq 0 ] || { hp_unlock; echo "status=error"; return 2; }
    fi
    again=$(plan_line_of "$WSDIR/progress.md")
```

Run: `grep -nE '\$t([^a-z_]|$)' <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t1-t-uses.txt`, then read it: no line falls inside `cmd_finish` (between `cmd_finish() {` and the next `^}`).

- [ ] **Step 4: Run E5-a green**

```bash
bash <sw>/run-slices.sh <worktree> plainfix finish final-head finaltail > <sw>/logs/t1-e5a.green.log 2>&1
```

Expected: exit 0, the log ends `STATUS: PASSED`.

- [ ] **Step 5: Docs and CHANGELOG for E5-a**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "A final-train takeover after a finish killed past its rename-aside puts the plan's workspace back and takes the plan over as an open one; beside a new workspace it names the copy and answers \`busy\`."
```

Expected: `refreshed docs/site/advanced/sdd-internals.md` and `refreshed docs/site/skills/subagent-driven-development.md`, nothing else. Re-read both pages: at plan time no sentence in them describes the takeover after a killed finish (`takeover` appears only in sdd-internals' dispatch-resume paragraph, `removing` only in finish's `live-jobs` sentence), so only the digest lines change.

- [ ] **Step 6: Commit E5-a**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t1-e5a.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t1-e5a.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t1-e5a.staged.diff
git -C <worktree> commit -m "fix(sdd-state): a final-train takeover after a killed finish restores the plan and takes it over as an open one"
```

Expected: lint exit 0; the scan prints `hits: 0`.

**Finding E5-d, a damaged `closing=`.**

- [ ] **Step 7: Write the E5-d tests**

Write `<sw>/snippets/t1-e5d-test.sh`:

```bash
# A takeover reads a missing or malformed closing= in the replaced lease as closing, at both takeover sites: an open plan's, and the orphan path after finish removed the workspace. A sibling's register on the branch then answers branch-closing.
dc="$TEST_ROOT/dc"; make_repo "$dc"; git -C "$dc" switch -q -c feat
mkdir -p "$dc/docs"; : > "$dc/docs/spec.md"
printf '# T\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$dc/docs/plan.md"; cp "$dc/docs/plan.md" "$dc/docs/plan2.md"; git -C "$dc" add docs; git -C "$dc" commit -qm plans
wsdc=$(run_sdd_dir "$dc" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsdc/progress.md"
wsdc2=$(run_sdd_dir "$dc" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsdc2/progress.md"
run_state "$dc" register docs/plan.md --session s1 --integration feat >/dev/null
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsdc/progress.md"
run_state "$dc" claim docs/plan.md final --session s1 >/dev/null
lease_dc=""; for dc_f in "$STATE_ROOT/$(state_key "$dc").final-"*; do case "$dc_f" in *.history) ;; *) [ -f "$dc_f" ] && lease_dc=$dc_f ;; esac; done
# dc_case <taker> <sed expression applied to the lease> <label>
dc_case() {
  sed "$2" "$lease_dc" > "$lease_dc.new" && mv -f "$lease_dc.new" "$lease_dc"
  out=$(run_state "$dc" claim docs/plan.md final --session "$1" --takeover 2>/dev/null); rc=$?
  out2=$(run_state "$dc" register docs/plan2.md --session s9 --integration feat 2>/dev/null); rc2=$?
  if [ "$rc" -eq 0 ] && [ "${out%% lease=*}" = "status=claimed task=final" ] && [ "$(sed -n 's/^session=//p' "$lease_dc")" = "$1" ] && [ "$(sed -n 's/^closing=//p' "$lease_dc")" = 1 ] && [ "$rc2" -eq 15 ] && [ "$out2" = "status=branch-closing" ]; then pass "$3"; else fail "$3 (rc=$rc: $out; closing=$(sed -n 's/^closing=//p' "$lease_dc"); register rc=$rc2: $out2)"; fi
}
dc_case s2 '/^closing=/d' "a takeover of an open plan keeps a missing closing= as closing"
dc_case s3 's/^closing=.*/closing=yes/' "a takeover of an open plan keeps a malformed closing= as closing"
rm -rf "$wsdc"
dc_case s4 '/^closing=/d' "a takeover after finish keeps a missing closing= as closing"
dc_case s5 's/^closing=.*/closing=yes/' "a takeover after finish keeps a malformed closing= as closing"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before '# Workspace names in the plan= field are encoded' <sw>/snippets/t1-e5d-test.sh`
Expected: exit 0 (the block lands after the `fk` block).

- [ ] **Step 8: Run E5-d red**

```bash
bash <sw>/make-red.sh <worktree> t1-e5d
bash <sw>/run-slices.sh <sw>/red/t1-e5d finaltail > <sw>/logs/t1-e5d.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t1-e5d.red.log > <sw>/logs/t1-e5d.red.fails
```

Expected: exit 1; the fails list holds the four `dc_case` labels (at e62fdb5 each takeover writes `closing=0` and the sibling registers) and the two E5-a labels (that fix is not in the red tree).

- [ ] **Step 9: Implement E5-d**

In `sdd-state`, with the Edit tool and `replace_all`, replace `[ "$lclosing" = 1 ] || lclosing=0` (two occurrences, `claim_final` and `claim_final_orphan`) with `[ "$lclosing" = 0 ] || lclosing=1`. Then update both comments. Replace

```text
      # A takeover keeps the replaced lease's closing=: once the closing has
      # found the branch free of open plans, a new holder must not reopen it
      # to registrations and task claims while the branch can still be
      # deleted under them.
```

with

```text
      # A takeover keeps the replaced lease's closing=: once the closing has
      # found the branch free of open plans, a new holder must not reopen it
      # to registrations and task claims while the branch can still be
      # deleted under them. Only an exact 0 reads as open: a missing or
      # damaged value reads as closing, so a damaged lease never reopens a
      # branch being torn down.
```

and replace

```text
  # it. Its closing= is kept, so a branch the holder had marked closing is
  # not reopened to sibling registrations by the takeover. Nothing else is
```

with

```text
  # it. Its closing= is kept, and only an exact 0 reads as open, so a branch
  # the holder had marked closing, or whose lease is damaged, is not reopened
  # to sibling registrations by the takeover. Nothing else is
```

- [ ] **Step 10: Run E5-d green**

```bash
bash <sw>/run-slices.sh <worktree> plainfix finish final-head finaltail > <sw>/logs/t1-e5d.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 11: Docs and CHANGELOG for E5-d**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "A takeover reads a missing or malformed \`closing=\` in the replaced lease as closing, so a damaged lease never reopens a branch being torn down."
```

Expected: the same two pages refreshed; neither describes `closing=` (no match for `closing=` in either at plan time), so only digests change.

- [ ] **Step 12: Commit E5-d**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t1-e5d.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t1-e5d.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t1-e5d.staged.diff
git -C <worktree> commit -m "fix(sdd-state): a takeover reads a missing or malformed closing= as closing"
```

Expected: lint exit 0; `hits: 0`.

- [ ] **Step 13: Verify Task 1**

```bash
bash <sw>/run-slices.sh <worktree> plainfix finish final-head finaltail claim2 > <sw>/logs/t1.slices.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t1` (changed script: `sdd-state`). Expected: every slice passes and the block's expectations hold. Report: the two red runs with their FAIL labels; no exempt tests in this task.

Correction (2026-11-09), decision 5 (A final-train takeover restores a killed finish's copy first): the takeover runs its copy check on every final takeover, not only when `progress.md` is missing. A copy beside any workspace at the path, with or without a ledger, answers `busy` with the copy named, as finish does. A copy comes back only when the path is free, the copy holds `progress.md` and, on the branch backend, the state branch still tracks `plans/<ws>`; any other copy stays where it is and the claim takes the orphan path. The takeover never moves a workspace aside. The Task 1 Codex task gate found these cases in rounds 1 to 3; the round-3 change was applied beyond the task's five-round cap at the user's direction, checked by a scoped re-review and the covering slices only.

### Task 2: Amend

**Risk tier:** high — amend writes the plan ref and other worktrees' files and indexes after a compare-and-swap: concurrency code and worktree writes.

**Depends on:** Task 1

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Test: `tests/sdd/test-sdd-state.sh`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`

**Interfaces:**
- Consumes: `amend_wt_index <worktree>` ("<mode> <blob>" or nothing), `amend_wt_plan_clean <worktree>`, `enc`, `cmd_amend`'s scope (`REPO`, `ref`, `rel`, `record`, `P`, `commit`).
- Produces: `amend_ref_worktrees` fills `AMEND_WT` (paths) and `AMEND_WT_GONE` (per entry: 0 present, 1 directory missing, 2 directory missing and the worktree locked), keeping missing ones; `amend_wt_note` (its per-record helper); `amend_refresh_differs <worktree>` and `amend_refresh_settle <worktree>` (the two refresh error lines); `amend_aside_matches <worktree> <aside copy> <"mode blob">`; `amend_refresh_one <worktree> <old commit> <new commit>`. Seams: `HYPERPOWERS_TEST_WRITER_AT=amend-wt-before-swap:<sha>:<path>`, `amend-refresh-before-rename:<delete|chmod|unlink>`, `amend-refresh-after-rename`, each touching `$HYPERPOWERS_TEST_SEAM_MARK` when it fires. Task 4 adds `amend-symref-before-swap` beside them; Task 5's `enc` test reuses the `aw` area.

**Mirror:** `sdd-state:2254-2256` (the `amend-before-swap` seam's shape); `tests/sdd/test-sdd-state.sh:4240-4248` (the lost-swap test's shape).

**Finding E6-a, a lost swap.**

- [ ] **Step 1: Rewrite the lost-swap test**

The existing test at `test-sdd-state.sh:4240-4248` runs its lost swap while `am_a` has the plan ref checked out, which E6-a turns into a refusal. It becomes the refusal test, and the recompute is checked again with `am_a` detached. Write `<sw>/snippets/t2-e6a-am.sh`:

```bash
# A lost compare-and-swap: a writer moves the plan ref between the record and the swap. While a worktree has the plan ref checked out the amendment is refused as checked-out, because that writer left the worktree at the old head; with none, a moved head with the same plan is recomputed, and one whose plan changed is stale. Neither leaves a record.
head3=$(git -C "$am_a" rev-parse feat)
adv_am=$(git -C "$am_a" commit-tree "$(git -C "$am_a" rev-parse "feat^{tree}")" -p "$head3" -m "advance" 2>/dev/null)
sed 's/^### Task 1: A$/### Task 1: A1/' "$TEST_ROOT/am.cand3" > "$TEST_ROOT/am.cand4"
idx_am=$(git -C "$am_a" ls-files -s)
out=$(cd "$am_a" && HYPERPOWERS_TEST_WRITER_AT="amend-before-swap:$adv_am" bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/am.cand4" --base "$base3" --accept 'tasks=1,2 path=src/x.sh' --message "a1" 2>"$TEST_ROOT/am.lost.err"); rc=$?
if [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=$am_a" ] && grep -qF "the plan ref feat moved during the amendment while $am_a has it checked out; bring that worktree to the new head, then run the same amend again" "$TEST_ROOT/am.lost.err" && [ "$(git -C "$am_a" rev-parse feat)" = "$adv_am" ] && [ -z "$(ls -A "$wsam/amends" 2>/dev/null)" ] && [ "$(git -C "$am_a" ls-files -s)" = "$idx_am" ]; then pass "a lost swap while a worktree has the plan ref checked out is refused as checked-out, the index untouched"; else fail "a lost swap while a worktree has the plan ref checked out is refused as checked-out, the index untouched (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/am.lost.err"))"; fi
git -C "$am_a" switch -q --detach
adv2_am=$(git -C "$am_a" commit-tree "$(git -C "$am_a" rev-parse "feat^{tree}")" -p "$(git -C "$am_a" rev-parse feat)" -m "advance again" 2>/dev/null)
out=$(cd "$am_a" && HYPERPOWERS_TEST_WRITER_AT="amend-before-swap:$adv2_am" bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/am.cand4" --base "$base3" --accept 'tasks=1,2 path=src/x.sh' --message "a1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$(git -C "$am_a" rev-parse "feat^")" = "$adv2_am" ] && [ -z "$(ls -A "$wsam/amends" 2>/dev/null)" ]; then pass "a lost swap is recomputed on the moved head"; else fail "amend lost swap (rc=$rc: $out parent=$(git -C "$am_a" rev-parse "feat^" 2>/dev/null))"; fi
```

Run: `python3 <sw>/replace-range.py <worktree>/tests/sdd/test-sdd-state.sh '# A lost compare-and-swap: a writer moves the plan ref between the record and the swap.' 'pass "a lost swap is recomputed on the moved head"' <sw>/snippets/t2-e6a-am.sh`
Expected: `replaced lines 4240-4248 of ...` (Task 1 added lines before 4068, so the numbers shift by Task 1's insertions; any pair is fine as long as the tool exits 0). The tests after it (the restated acceptance, the stale swap at `other_commit`, the unpublished record) stay as they are; with `am_a` detached the stale swap still answers 14.

- [ ] **Step 2: Add the worktree fixture and the late-worktree test**

Write `<sw>/snippets/t2-e6a-aw.sh`:

```bash
# Amend and the worktrees on the plan ref: a lost swap while one has the ref checked out, a registered worktree whose directory is gone, and the refresh that moves the plan file aside before git writes the new plan.
aw="$TEST_ROOT/aw"; make_repo "$aw"; git -C "$aw" switch -q -c feat
mkdir -p "$aw/docs"; : > "$aw/docs/spec.md"
printf '# W\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 2: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$aw/docs/plan.md"
git -C "$aw" add docs; git -C "$aw" commit -qm plan
wsaw=$(run_sdd_dir "$aw" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsaw/progress.md"
run_state "$aw" register docs/plan.md --session s1 --integration feat >/dev/null
git -C "$aw" switch -q --detach
seam_aw="$TEST_ROOT/aw.seam"
# aw_amend <label> [VAR=value...]: renames Task 2 to B-<label> in the plan ref's current plan, from that plan's blob; out, rc and aw.err hold the answer.
aw_amend() {
  local label=$1; shift
  aw_base=$(git -C "$aw" rev-parse feat:docs/plan.md)
  git -C "$aw" show feat:docs/plan.md | sed "s/^### Task 2: .*/### Task 2: B-$label/" > "$TEST_ROOT/aw.$label"
  rm -f "$seam_aw"
  out=$(cd "$aw" && env HYPERPOWERS_TEST_SEAM_MARK="$seam_aw" "$@" bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/aw.$label" --base "$aw_base" --message "$label" 2>"$TEST_ROOT/aw.err"); rc=$?
}
# aw_retry <label>: the same amend again, with the same --from and --base.
aw_retry() {
  out=$(cd "$aw" && bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/aw.$1" --base "$aw_base" --message "$1" 2>"$TEST_ROOT/aw.err"); rc=$?
}
mv_aw=$(git -C "$aw" commit-tree "$(git -C "$aw" rev-parse "feat^{tree}")" -p "$(git -C "$aw" rev-parse feat)" -m "moved by another writer")
aw_amend late "HYPERPOWERS_TEST_WRITER_AT=amend-wt-before-swap:$mv_aw:$TEST_ROOT/aw-late"
if [ -f "$seam_aw" ] && [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=$TEST_ROOT/aw-late" ] && grep -qF "the plan ref feat moved during the amendment while $TEST_ROOT/aw-late has it checked out" "$TEST_ROOT/aw.err" && [ "$(git -C "$aw" rev-parse feat)" = "$mv_aw" ] && [ -z "$(ls -A "$wsaw/amends" 2>/dev/null)" ]; then pass "a worktree that checks the plan ref out after the scan, before a lost swap, refuses the amendment by name"; else fail "a worktree that checks the plan ref out after the scan, before a lost swap, refuses the amendment by name (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
git -C "$aw" worktree remove --force "$TEST_ROOT/aw-late" >/dev/null 2>&1
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'echo "merge-back: the integration ref' <sw>/snippets/t2-e6a-aw.sh`
Expected: exit 0.

- [ ] **Step 3: Run E6-a red**

Write `<sw>/snippets/t2-e6a-seam.txt` (the seam exactly as the fix keeps it):

```bash
    # Test seam: HYPERPOWERS_TEST_WRITER_AT=amend-wt-before-swap:<sha>:<path>
    # adds a worktree at <path> with the plan ref checked out and then moves
    # the ref to <sha>, both after the scan and before the swap, once.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
      amend-wt-before-swap:*)
        [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
        sv=${HYPERPOWERS_TEST_WRITER_AT#amend-wt-before-swap:}
        git -C "$REPO" worktree add -q "${sv#*:}" "$ref" >/dev/null 2>&1
        git -C "$REPO" update-ref "refs/heads/$ref" "${sv%%:*}" 2>/dev/null
        HYPERPOWERS_TEST_WRITER_AT="" ;;
    esac
```

```bash
bash <sw>/make-red.sh <worktree> t2-e6a
python3 <sw>/insert-at.py <sw>/red/t2-e6a/skills/subagent-driven-development/scripts/sdd-state after 'in amend-before-swap:*) git -C "$REPO" update-ref' <sw>/snippets/t2-e6a-seam.txt
bash <sw>/run-slices.sh <sw>/red/t2-e6a amend > <sw>/logs/t2-e6a.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t2-e6a.red.log > <sw>/logs/t2-e6a.red.fails
```

Expected: exit 1; the fails list holds "a lost swap while a worktree has the plan ref checked out is refused as checked-out, the index untouched" and "a worktree that checks the plan ref out after the scan, before a lost swap, refuses the amendment by name" (at e62fdb5 both retry and publish). "a lost swap is recomputed on the moved head" may fail too, downstream of the first (the red run's first amend already moved the ref); nothing else fails.

- [ ] **Step 4: Implement E6-a**

In `cmd_amend`, with the Edit tool. Replace the locals line

```text
  local lease lowner line integ c sid full base_unknown="" errf rbase uerr wb a all
```

with

```text
  local lease lowner line integ c sid full base_unknown="" errf rbase uerr wb a all sv
```

Replace

```text
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in amend-before-swap:*) git -C "$REPO" update-ref "refs/heads/$ref" "${HYPERPOWERS_TEST_WRITER_AT#amend-before-swap:}" 2>/dev/null; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

with that same line followed by the content of `<sw>/snippets/t2-e6a-seam.txt`. Then replace

```text
      echo "sdd-state: update-ref failed and the plan ref $ref is unchanged at ${P:0:7}: $uerr" >&2; echo "status=error"; return 2
    fi
  done
```

with

```text
      echo "sdd-state: update-ref failed and the plan ref $ref is unchanged at ${P:0:7}: $uerr" >&2; echo "status=error"; return 2
    fi
    # The ref moved: another writer published while this attempt ran, and a
    # worktree on the plan ref was left at the old head by it. The refresh
    # would bring only the plan over, so the writer's other changes would
    # stay staged there as reverts. The list is read here, in this shell
    # (amend_wt_blocker ran inside a command substitution), and after the
    # failure, so a worktree that checked the ref out since this attempt's
    # scan counts too; one that checks it out later gets the moved head.
    amend_ref_worktrees || { rm -f "$record"; hp_unlock; echo "sdd-state: the worktrees of $REPO could not be listed" >&2; echo "status=error"; return 2; }
    if [ "${#AMEND_WT[@]}" -gt 0 ]; then
      rm -f "$record"; hp_unlock
      echo "sdd-state: the plan ref $ref moved during the amendment while ${AMEND_WT[0]} has it checked out; bring that worktree to the new head, then run the same amend again" >&2
      echo "status=checked-out worktree=$(enc "${AMEND_WT[0]}")"; return 13
    fi
  done
```

- [ ] **Step 5: Run E6-a green**

```bash
bash <sw>/run-slices.sh <worktree> amend > <sw>/logs/t2-e6a.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 6: Docs and CHANGELOG for E6-a**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`amend\` answers \`checked-out\` when another writer moved the plan ref during the amendment while a worktree has that ref checked out, instead of retrying over a worktree left at the old head."
```

Expected: the two SDD pages refreshed. sdd-internals' amend bullet (`:63`) says what amend changes, not how it treats worktrees, so only digests change.

- [ ] **Step 7: Commit E6-a**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t2-e6a.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t2-e6a.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t2-e6a.staged.diff
git -C <worktree> commit -m "fix(sdd-state): amend answers checked-out when a lost swap leaves a worktree on the plan ref"
```

Expected: lint exit 0; `hits: 0`.

**Finding E6-d, a missing worktree directory.**

- [ ] **Step 8: Write the E6-d tests**

Write `<sw>/snippets/t2-e6d-test.sh`:

```bash
# A registered worktree on the plan ref whose directory is gone blocks the amendment until it is restored or pruned; a locked one needs git worktree unlock before git worktree prune removes it.
git -C "$aw" worktree add -q "$TEST_ROOT/aw-gone" feat >/dev/null 2>&1; mv "$TEST_ROOT/aw-gone" "$TEST_ROOT/aw-gone.away"
h_aw=$(git -C "$aw" rev-parse feat)
aw_amend gone
if [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=$TEST_ROOT/aw-gone" ] && grep -qF "the worktree $TEST_ROOT/aw-gone has the plan ref feat checked out but its directory is missing; restore it or run git worktree prune, then run the same amend again" "$TEST_ROOT/aw.err" && [ "$(git -C "$aw" rev-parse feat)" = "$h_aw" ]; then pass "a worktree on the plan ref whose directory is missing refuses the amendment by name, the ref unmoved"; else fail "a worktree on the plan ref whose directory is missing refuses the amendment by name, the ref unmoved (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
git -C "$aw" worktree prune
aw_retry gone
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ]; then pass "after git worktree prune the same amend succeeds"; else fail "after git worktree prune the same amend succeeds (rc=$rc: $out)"; fi
rm -rf "$TEST_ROOT/aw-gone.away"
git -C "$aw" worktree add -q "$TEST_ROOT/aw-lock" feat >/dev/null 2>&1; git -C "$aw" worktree lock "$TEST_ROOT/aw-lock"; mv "$TEST_ROOT/aw-lock" "$TEST_ROOT/aw-lock.away"
h_aw=$(git -C "$aw" rev-parse feat)
aw_amend locked
if [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=$TEST_ROOT/aw-lock" ] && grep -qF "the worktree $TEST_ROOT/aw-lock has the plan ref feat checked out but its directory is missing and the worktree is locked; restore it, or run git worktree unlock $TEST_ROOT/aw-lock and then git worktree prune, then run the same amend again" "$TEST_ROOT/aw.err" && [ "$(git -C "$aw" rev-parse feat)" = "$h_aw" ]; then pass "a locked worktree whose directory is missing refuses with the unlock-and-prune line"; else fail "a locked worktree whose directory is missing refuses with the unlock-and-prune line (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
git -C "$aw" worktree prune
aw_retry locked
if [ "$rc" -eq 13 ] && [ "$(git -C "$aw" rev-parse feat)" = "$h_aw" ]; then pass "git worktree prune alone leaves a locked missing worktree refusing the amendment"; else fail "git worktree prune alone leaves a locked missing worktree refusing the amendment (rc=$rc: $out)"; fi
git -C "$aw" worktree unlock "$TEST_ROOT/aw-lock"; git -C "$aw" worktree prune
aw_retry locked
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ]; then pass "after git worktree unlock and git worktree prune the same amend succeeds"; else fail "after git worktree unlock and git worktree prune the same amend succeeds (rc=$rc: $out)"; fi
mv2_aw=$(git -C "$aw" commit-tree "$(git -C "$aw" rev-parse "feat^{tree}")" -p "$(git -C "$aw" rev-parse feat)" -m "moved again by another writer")
aw_amend lategone "HYPERPOWERS_TEST_WRITER_AT=amend-gone-before-swap:$mv2_aw:$TEST_ROOT/aw-lategone"
if [ -f "$seam_aw" ] && [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=$TEST_ROOT/aw-lategone" ] && grep -qF "the plan ref feat moved during the amendment while $TEST_ROOT/aw-lategone has it checked out" "$TEST_ROOT/aw.err" && [ "$(git -C "$aw" rev-parse feat)" = "$mv2_aw" ] && [ ! -e "$wsaw/amends/$(git -C "$aw" hash-object "$TEST_ROOT/aw.lategone")" ]; then pass "a worktree whose directory goes missing after the scan, before a lost swap, refuses the amendment by name"; else fail "a worktree whose directory goes missing after the scan, before a lost swap, refuses the amendment by name (seam=$([ -f "$seam_aw" ] && echo 1 || echo 0) rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
rm -rf "$TEST_ROOT/aw-lategone.away"; git -C "$aw" worktree prune
rm -rf "$TEST_ROOT/aw-lock.away"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'worktree remove --force "$TEST_ROOT/aw-late"' <sw>/snippets/t2-e6d-test.sh`
Expected: exit 0.

- [ ] **Step 9: Run E6-d red**

Write `<sw>/snippets/t2-e6d-seam.txt`, the whole seam as E6-d leaves it (Step 3's `amend-wt-before-swap` seam with the `amend-gone-before-swap` arm Step 10 adds):

```bash
    # Test seam: HYPERPOWERS_TEST_WRITER_AT=amend-wt-before-swap:<sha>:<path>
    # adds a worktree at <path> with the plan ref checked out and then moves
    # the ref to <sha>, both after the scan and before the swap, once.
    # amend-gone-before-swap:<sha>:<path> does the same and moves <path> to
    # <path>.away before the ref moves, so that worktree's directory is
    # missing when the swap fails.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
      amend-gone-before-swap:*)
        [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
        sv=${HYPERPOWERS_TEST_WRITER_AT#amend-gone-before-swap:}
        git -C "$REPO" worktree add -q "${sv#*:}" "$ref" >/dev/null 2>&1
        mv "${sv#*:}" "${sv#*:}.away"
        git -C "$REPO" update-ref "refs/heads/$ref" "${sv%%:*}" 2>/dev/null
        HYPERPOWERS_TEST_WRITER_AT="" ;;
      amend-wt-before-swap:*)
        [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
        sv=${HYPERPOWERS_TEST_WRITER_AT#amend-wt-before-swap:}
        git -C "$REPO" worktree add -q "${sv#*:}" "$ref" >/dev/null 2>&1
        git -C "$REPO" update-ref "refs/heads/$ref" "${sv%%:*}" 2>/dev/null
        HYPERPOWERS_TEST_WRITER_AT="" ;;
    esac
```

```bash
bash <sw>/make-red.sh <worktree> t2-e6d
python3 <sw>/insert-at.py <sw>/red/t2-e6d/skills/subagent-driven-development/scripts/sdd-state after 'in amend-before-swap:*) git -C "$REPO" update-ref' <sw>/snippets/t2-e6d-seam.txt
bash <sw>/run-slices.sh <sw>/red/t2-e6d amendwt > <sw>/logs/t2-e6d.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t2-e6d.red.log > <sw>/logs/t2-e6d.red.fails
```

Expected: exit 1; the fails list holds "a worktree on the plan ref whose directory is missing refuses the amendment by name, the ref unmoved", "a locked worktree whose directory is missing refuses with the unlock-and-prune line", "git worktree prune alone leaves a locked missing worktree refusing the amendment" and "a worktree whose directory goes missing after the scan, before a lost swap, refuses the amendment by name" (at e62fdb5 the missing worktree is skipped and each amend publishes), plus the E6-a late-worktree label (at e62fdb5 the lost swap retries and publishes). The two "the same amend succeeds" labels need not fail (at e62fdb5 the retry answers `already=1`). The lategone label's FAIL line shows `seam=1`, so the seam ran and the failure is the defect's.

- [ ] **Step 10: Implement E6-d**

In `sdd-state`, with the Edit tool. Replace `amend_ref_worktrees` with its comment:

```text
# Fills AMEND_WT with the worktrees of the plan repository that have the plan
# ref checked out, as git worktree list names them. A worktree whose
# directory is gone holds no copy. Reads REPO and ref from cmd_amend.
amend_ref_worktrees() {
  local f wt="" all
  AMEND_WT=()
  all=$(mktemp "${TMPDIR:-/tmp}/sdd-amend-wt.XXXXXX") || return 1
  # -z, since a worktree path may hold a newline.
  if ! git -C "$REPO" worktree list --porcelain -z > "$all"; then rm -f "$all"; return 1; fi
  while IFS= read -r -d '' f; do
    case "$f" in
      "worktree "*) wt=${f#worktree } ;;
      "branch refs/heads/$ref") if [ -d "$wt" ]; then AMEND_WT[${#AMEND_WT[@]}]=$wt; fi ;;
    esac
  done < "$all"
  rm -f "$all"
}
```

with

```text
# Fills AMEND_WT with the worktrees of the plan repository that have the plan
# ref checked out, as git worktree list names them, and AMEND_WT_GONE beside
# it: 0 when the directory is there, 1 when it is missing, 2 when it is
# missing and the worktree is locked, which git worktree prune leaves alone.
# A missing one is kept: it would come back with the old plan staged against
# the new head. Reads REPO and ref from cmd_amend.
amend_ref_worktrees() {
  local f wt="" on=0 locked=0 all
  AMEND_WT=(); AMEND_WT_GONE=()
  all=$(mktemp "${TMPDIR:-/tmp}/sdd-amend-wt.XXXXXX") || return 1
  # -z, since a worktree path may hold a newline.
  if ! git -C "$REPO" worktree list --porcelain -z > "$all"; then rm -f "$all"; return 1; fi
  while IFS= read -r -d '' f; do
    case "$f" in
      "worktree "*) amend_wt_note; wt=${f#worktree }; on=0; locked=0 ;;
      "branch refs/heads/$ref") on=1 ;;
      locked|"locked "*) locked=1 ;;
      '') amend_wt_note ;;
    esac
  done < "$all"
  amend_wt_note
  rm -f "$all"
}
# Notes the worktree record just read when it has the plan ref checked out,
# once. Reads wt, on and locked from amend_ref_worktrees.
amend_wt_note() {
  [ "$on" -eq 1 ] || return 0
  AMEND_WT[${#AMEND_WT[@]}]=$wt
  if [ -d "$wt" ]; then AMEND_WT_GONE[${#AMEND_WT_GONE[@]}]=0
  elif [ "$locked" -eq 1 ]; then AMEND_WT_GONE[${#AMEND_WT_GONE[@]}]=2
  else AMEND_WT_GONE[${#AMEND_WT_GONE[@]}]=1; fi
  on=0
}
```

Replace the start of `amend_wt_blocker`

```text
amend_wt_blocker() {
  local i=0 w e
  amend_ref_worktrees || return 1
  while [ "$i" -lt "${#AMEND_WT[@]}" ]; do
```

with

```text
amend_wt_blocker() {
  local i=0 w e
  amend_ref_worktrees || return 1
  # A registered worktree whose directory is gone blocks first, before any
  # other is checked; a locked one needs git worktree unlock before git
  # worktree prune removes it.
  while [ "$i" -lt "${#AMEND_WT[@]}" ]; do
    w=${AMEND_WT[$i]}
    case "${AMEND_WT_GONE[$i]}" in
      1) echo "sdd-state: the worktree $w has the plan ref $ref checked out but its directory is missing; restore it or run git worktree prune, then run the same amend again" >&2; printf '%s\n' "$w"; return 0 ;;
      2) echo "sdd-state: the worktree $w has the plan ref $ref checked out but its directory is missing and the worktree is locked; restore it, or run git worktree unlock $w and then git worktree prune, then run the same amend again" >&2; printf '%s\n' "$w"; return 0 ;;
    esac
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "${#AMEND_WT[@]}" ]; do
```

Replace

```text
# <old commit> <new commit>: brings every worktree on the plan ref from the
```

with

```text
# <worktree>: the refresh error for a copy that is missing or differs from
# its index entry, and for a worktree whose directory is gone.
amend_refresh_differs() {
  echo "sdd-state: the plan ref $ref carries the amendment, but the worktree $1 could not be refreshed to it: its copy of $rel is missing or differs from its index entry; settle that copy, then run the same amend again" >&2
}
# <old commit> <new commit>: brings every worktree on the plan ref from the
```

and in `amend_refresh` replace

```text
    w=${AMEND_WT[$i]}; i=$((i + 1))
    git -C "$w" update-index -q --refresh >/dev/null 2>&1
    if ! amend_wt_plan_clean "$w"; then
      echo "sdd-state: the plan ref $ref carries the amendment, but the worktree $w could not be refreshed to it: its copy of $rel is missing or differs from its index entry; settle that copy, then run the same amend again" >&2
      return 1
    fi
```

with

```text
    w=${AMEND_WT[$i]}
    # A directory that went missing since the scan cannot be refreshed: the
    # missing-copy error, and the record stays for the same amend run again.
    if [ "${AMEND_WT_GONE[$i]}" != 0 ]; then amend_refresh_differs "$w"; return 1; fi
    i=$((i + 1))
    git -C "$w" update-index -q --refresh >/dev/null 2>&1
    if ! amend_wt_plan_clean "$w"; then
      amend_refresh_differs "$w"
      return 1
    fi
```

Finally, add the `amend-gone-before-swap` arm to E6-a's seam in `cmd_amend`, so a worktree directory can go missing after the scan and before a lost swap. Replace

```text
    # the ref to <sha>, both after the scan and before the swap, once.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
      amend-wt-before-swap:*)
```

with

```text
    # the ref to <sha>, both after the scan and before the swap, once.
    # amend-gone-before-swap:<sha>:<path> does the same and moves <path> to
    # <path>.away before the ref moves, so that worktree's directory is
    # missing when the swap fails.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
      amend-gone-before-swap:*)
        [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
        sv=${HYPERPOWERS_TEST_WRITER_AT#amend-gone-before-swap:}
        git -C "$REPO" worktree add -q "${sv#*:}" "$ref" >/dev/null 2>&1
        mv "${sv#*:}" "${sv#*:}.away"
        git -C "$REPO" update-ref "refs/heads/$ref" "${sv%%:*}" 2>/dev/null
        HYPERPOWERS_TEST_WRITER_AT="" ;;
      amend-wt-before-swap:*)
```

The seam now matches `<sw>/snippets/t2-e6d-seam.txt`. E6-a's post-failure listing needs no change: `AMEND_WT` now holds missing entries too, so a worktree whose directory vanished during the attempt also answers `checked-out`.

- [ ] **Step 11: Run E6-d green**

```bash
bash <sw>/run-slices.sh <worktree> amend > <sw>/logs/t2-e6d.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 12: Docs and CHANGELOG for E6-d**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`amend\` refuses while a worktree registered on the plan ref has lost its directory, naming the \`git worktree prune\` (or \`unlock\` and \`prune\`) that clears it."
```

Expected: the two SDD pages refreshed, digests only.

- [ ] **Step 13: Commit E6-d**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t2-e6d.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t2-e6d.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t2-e6d.staged.diff
git -C <worktree> commit -m "fix(sdd-state): amend refuses while a worktree on the plan ref has lost its directory"
```

Expected: lint exit 0; `hits: 0`.

**Finding E6-b, a deletion during the refresh.**

The spec asks for an error naming both paths when a file was created at the plan path while the copy was aside, and quotes no line for it; this plan writes it: `sdd-state: the plan ref <ref> carries the amendment, but the worktree <w> could not be refreshed to it: a file appeared at <path> while its copy was aside at <aside>; keep the one you want at <path>, then run the same amend again`. Every other refresh failure keeps one of the two existing lines (`amend_refresh_differs`, `amend_refresh_settle`).

- [ ] **Step 14: Write the E6-b tests**

Write `<sw>/snippets/t2-e6b-test.sh`:

```bash
# The refresh moves the plan file aside and checks it there before git writes the new plan: a deletion fails the rename, a file created meanwhile is left alone, and a changed file is put back unchanged.
awt="$TEST_ROOT/aw-wt"; git -C "$aw" worktree add -q "$awt" feat >/dev/null 2>&1
aw_asides() { find "$awt/docs" -name '.plan.md.sdd-amend-*' ! -name '*EARLY1' | grep -c .; }
aw_amend plain
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$(git -C "$awt" hash-object docs/plan.md)" = "$(git -C "$aw" rev-parse feat:docs/plan.md)" ] && [ -z "$(git -C "$awt" status --porcelain)" ] && [ "$(aw_asides)" = 0 ]; then pass "a refresh leaves the new plan in the worktree and no copy aside"; else fail "a refresh leaves the new plan in the worktree and no copy aside (rc=$rc: $out: $(git -C "$awt" status --porcelain | tr '\n' '|'))"; fi
aw_amend del HYPERPOWERS_TEST_WRITER_AT=amend-refresh-before-rename:delete
n_aw=$(git -C "$aw" hash-object "$TEST_ROOT/aw.del")
if [ -f "$seam_aw" ] && [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$awt/docs/plan.md" ] && [ -f "$wsaw/amends/$n_aw" ] && grep -qF "the worktree $awt could not be refreshed to it: its copy of docs/plan.md is missing or differs from its index entry" "$TEST_ROOT/aw.err" && [ "$(aw_asides)" = 0 ]; then pass "a plan file deleted during the refresh stays deleted, the record kept"; else fail "a plan file deleted during the refresh stays deleted, the record kept (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
git -C "$awt" checkout-index -f -- docs/plan.md
aw_retry del
if [ "$rc" -eq 0 ] && [ "${out##* }" = "already=1" ] && [ "$(git -C "$awt" hash-object docs/plan.md)" = "$n_aw" ]; then pass "once the deleted file is restored the same amend finishes the refresh"; else fail "once the deleted file is restored the same amend finishes the refresh (rc=$rc: $out)"; fi
aw_amend new HYPERPOWERS_TEST_WRITER_AT=amend-refresh-after-rename
n_aw=$(git -C "$aw" hash-object "$TEST_ROOT/aw.new")
aside_aw=$(find "$awt/docs" -name '.plan.md.sdd-amend-*' ! -name '*EARLY1' | head -n 1)
if [ -f "$seam_aw" ] && [ "$rc" -eq 2 ] && [ "$(cat "$awt/docs/plan.md")" = "created during the refresh" ] && [ -n "$aside_aw" ] && grep -qF "a file appeared at $awt/docs/plan.md while its copy was aside at $aside_aw" "$TEST_ROOT/aw.err" && [ -f "$wsaw/amends/$n_aw" ]; then pass "a file created at the plan path during the refresh is left alone, the copy kept aside and both named"; else fail "a file created at the plan path during the refresh is left alone, the copy kept aside and both named (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
rm -f "$awt/docs/plan.md"; [ -z "$aside_aw" ] || rm -f "$aside_aw"; git -C "$awt" checkout-index -f -- docs/plan.md
aw_retry new
if [ "$rc" -eq 0 ] && [ "${out##* }" = "already=1" ]; then pass "the same amend finishes once the created file is settled"; else fail "the same amend finishes once the created file is settled (rc=$rc: $out)"; fi
aw_amend mode HYPERPOWERS_TEST_WRITER_AT=amend-refresh-before-rename:chmod
n_aw=$(git -C "$aw" hash-object "$TEST_ROOT/aw.mode")
if [ -f "$seam_aw" ] && [ "$rc" -eq 2 ] && [ -x "$awt/docs/plan.md" ] && [ "$(git -C "$awt" hash-object docs/plan.md)" = "$(git -C "$awt" rev-parse :docs/plan.md)" ] && [ "$(aw_asides)" = 0 ] && [ -f "$wsaw/amends/$n_aw" ]; then pass "a plan file whose executable bit flipped during the refresh is put back unchanged"; else fail "a plan file whose executable bit flipped during the refresh is put back unchanged (rc=$rc: $out)"; fi
chmod -x "$awt/docs/plan.md"
aw_retry mode
if [ "$rc" -eq 0 ] && [ "${out##* }" = "already=1" ]; then pass "the same amend finishes once the executable bit is restored"; else fail "the same amend finishes once the executable bit is restored (rc=$rc: $out)"; fi
printf 'early\n' > "$awt/docs/.plan.md.sdd-amend-EARLY1"
aw_amend early
if [ "$rc" -eq 0 ] && [ "$(cat "$awt/docs/.plan.md.sdd-amend-EARLY1")" = early ] && [ "$(aw_asides)" = 0 ]; then pass "a file left at an earlier run's aside name stays untouched"; else fail "a file left at an earlier run's aside name stays untouched (rc=$rc: $out)"; fi
rm -f "$awt/docs/.plan.md.sdd-amend-EARLY1"; git -C "$aw" worktree remove --force "$awt" >/dev/null 2>&1
# The link variant: where the index holds a symbolic link, a regular file holding the link's target text hashes to the same blob, and is still no match. hp_plan_dir refuses a linked plan path, so the plan line is written by hand and the caller stays on main, where the plan is a regular file.
al="$TEST_ROOT/al"; make_repo "$al"
mkdir -p "$al/docs"; : > "$al/docs/spec.md"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Depends on:** none\n' > "$al/docs/plan.md"; git -C "$al" add docs; git -C "$al" commit -qm plan
git -C "$al" switch -q -c feat; rm "$al/docs/plan.md"; ln -s plan-target "$al/docs/plan.md"; printf 'plan-target' > "$al/docs/plan-target"; git -C "$al" add docs; git -C "$al" commit -qm "plan as a link"; git -C "$al" switch -q main
wsal=$(run_sdd_dir "$al" docs/plan.md 2>/dev/null); r7_al=$(git -C "$al" rev-list --max-parents=0 HEAD | cut -c1-7)
printf '# SDD ledger — plan: docs/plan.md\nplan: integration feat code-root %s plan-ref feat plan-root %s spec docs/spec.md\n' "$r7_al" "$r7_al" > "$wsal/progress.md"
git -C "$al" worktree add -q "$TEST_ROOT/al-wt" feat >/dev/null 2>&1
b_al=$(git -C "$al" rev-parse feat:docs/plan.md)
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A2\n\n**Depends on:** none\n' > "$TEST_ROOT/al.cand"
rm -f "$TEST_ROOT/al.seam"
out=$(cd "$al" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/al.seam" HYPERPOWERS_TEST_WRITER_AT=amend-refresh-before-rename:unlink bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/al.cand" --base "$b_al" --message link 2>"$TEST_ROOT/al.err"); rc=$?
if [ -f "$TEST_ROOT/al.seam" ] && [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qF "but the worktree $TEST_ROOT/al-wt could not be refreshed to it" "$TEST_ROOT/al.err" && [ -f "$TEST_ROOT/al-wt/docs/plan.md" ] && [ ! -L "$TEST_ROOT/al-wt/docs/plan.md" ] && [ "$(cat "$TEST_ROOT/al-wt/docs/plan.md")" = plan-target ]; then pass "a regular file holding a link's target text where the index holds the link is no match, and it is put back unchanged"; else fail "a regular file holding a link's target text where the index holds the link is no match, and it is put back unchanged (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/al.err"))"; fi
# A link whose target ends in a newline is compared whole: $(readlink) would drop the newline, read the clean link as changed, and put it back without it.
an="$TEST_ROOT/an"; make_repo "$an"
mkdir -p "$an/docs"; : > "$an/docs/spec.md"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Depends on:** none\n' > "$an/docs/plan.md"; git -C "$an" add docs; git -C "$an" commit -qm plan
t_an=$(printf 'plan-target\nx'); t_an=${t_an%x}
git -C "$an" switch -q -c feat; rm "$an/docs/plan.md"; ln -s "$t_an" "$an/docs/plan.md"; git -C "$an" add docs; git -C "$an" commit -qm "plan as a link whose target ends in a newline"; git -C "$an" switch -q main
wsan=$(run_sdd_dir "$an" docs/plan.md 2>/dev/null); r7_an=$(git -C "$an" rev-list --max-parents=0 HEAD | cut -c1-7)
printf '# SDD ledger — plan: docs/plan.md\nplan: integration feat code-root %s plan-ref feat plan-root %s spec docs/spec.md\n' "$r7_an" "$r7_an" > "$wsan/progress.md"
git -C "$an" worktree add -q "$TEST_ROOT/an-wt" feat >/dev/null 2>&1
b_an=$(git -C "$an" rev-parse feat:docs/plan.md)
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A2\n\n**Depends on:** none\n' > "$TEST_ROOT/an.cand"
out=$(cd "$an" && bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/an.cand" --base "$b_an" --message nl 2>"$TEST_ROOT/an.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ -z "$(git -C "$TEST_ROOT/an-wt" status --porcelain)" ]; then pass "a clean link whose target ends in a newline takes the refresh"; else fail "a clean link whose target ends in a newline takes the refresh (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/an.err"))"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'rm -rf "$TEST_ROOT/aw-lock.away"' <sw>/snippets/t2-e6b-test.sh`
Expected: exit 0.

- [ ] **Step 15: Run E6-b red**

Write `<sw>/snippets/t2-e6b-seams.txt` (the two seams exactly as the fix keeps them; in the red tree they sit right before the old `read-tree -m -u`, after `amend_wt_plan_clean` passed):

```bash
      # Test seam: HYPERPOWERS_TEST_WRITER_AT=amend-refresh-before-rename:<delete|chmod|unlink>
      # deletes the plan file, flips its executable bit, or replaces a
      # symbolic link with a regular file holding its target text, right
      # before the rename aside, once.
      case "${HYPERPOWERS_TEST_WRITER_AT:-}" in
        amend-refresh-before-rename:*)
          [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
          case "${HYPERPOWERS_TEST_WRITER_AT#amend-refresh-before-rename:}" in
            delete) rm -f "$w/$rel" ;;
            chmod) if [ -x "$w/$rel" ]; then chmod -x "$w/$rel"; else chmod +x "$w/$rel"; fi ;;
            unlink) lt=$(readlink "$w/$rel"); rm -f "$w/$rel"; printf '%s' "$lt" > "$w/$rel" ;;
          esac
          HYPERPOWERS_TEST_WRITER_AT="" ;;
      esac
      # Test seam: HYPERPOWERS_TEST_WRITER_AT=amend-refresh-after-rename
      # creates a file at the plan path right after the rename aside, once.
      case "${HYPERPOWERS_TEST_WRITER_AT:-}" in amend-refresh-after-rename) [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; printf 'created during the refresh\n' > "$w/$rel"; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

```bash
bash <sw>/make-red.sh <worktree> t2-e6b
python3 <sw>/insert-at.py <sw>/red/t2-e6b/skills/subagent-driven-development/scripts/sdd-state before '    if ! git -C "$w" read-tree -m -u "$1" "$2"; then' <sw>/snippets/t2-e6b-seams.txt
bash <sw>/run-slices.sh <sw>/red/t2-e6b amendwt > <sw>/logs/t2-e6b.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t2-e6b.red.log > <sw>/logs/t2-e6b.red.fails
```

Expected: exit 1; the fails list holds "a plan file deleted during the refresh stays deleted, the record kept" (at e62fdb5 `read-tree -m -u` writes the deleted file back), "once the deleted file is restored the same amend finishes the refresh" (at e62fdb5 the first call removed its record, so the retry is stale), and "a file created at the plan path during the refresh is left alone, the copy kept aside and both named" (at e62fdb5 there is no aside copy), plus the E6-a and E6-d labels, whose fixes and seam this red tree lacks. The plain refresh, the executable-bit, the earlier-aside, the link-variant and the newline-target link labels pass at e62fdb5: they are the exempt guards and control named in Global Constraints.

- [ ] **Step 16: Implement E6-b**

In `sdd-state`, with the Edit tool, replace the whole of `amend_refresh` with its comment, as Step 10 left it:

```text
# <old commit> <new commit>: brings every worktree on the plan ref from the
# old commit's plan to the new one's through git's own two-way update,
# read-tree -m -u. It touches only the paths the two commits differ in, the
# plan alone here, keeps the worktree's other changes, and refuses rather
# than overwrites a copy that is neither clean at the old blob nor already
# the new one. A copy that is missing or differs from its index entry is
# refused before git is asked, since git would write a deleted file back,
# so an edit or a deletion made since the check survives. The index's stat
# data is refreshed first, or a file rewritten with the same content would
# be taken for an edit. A worktree that cannot be brought over is an error,
# never skipped: its index would keep the old plan staged against the new
# head.
amend_refresh() {
  local i=0 w
  amend_ref_worktrees || { echo "sdd-state: the plan ref $ref carries the amendment, but the worktrees of $REPO could not be listed; run the same amend again" >&2; return 1; }
  while [ "$i" -lt "${#AMEND_WT[@]}" ]; do
    w=${AMEND_WT[$i]}
    # A directory that went missing since the scan cannot be refreshed: the
    # missing-copy error, and the record stays for the same amend run again.
    if [ "${AMEND_WT_GONE[$i]}" != 0 ]; then amend_refresh_differs "$w"; return 1; fi
    i=$((i + 1))
    git -C "$w" update-index -q --refresh >/dev/null 2>&1
    if ! amend_wt_plan_clean "$w"; then
      amend_refresh_differs "$w"
      return 1
    fi
    if ! git -C "$w" read-tree -m -u "$1" "$2"; then
      echo "sdd-state: the plan ref $ref carries the amendment, but the worktree $w could not be refreshed to it; settle what git names above in that worktree, then run the same amend again" >&2
      return 1
    fi
  done
}
```

with

````text
# <worktree>: the refresh error for a refusal git names itself.
amend_refresh_settle() {
  echo "sdd-state: the plan ref $ref carries the amendment, but the worktree $1 could not be refreshed to it; settle what git names above in that worktree, then run the same amend again" >&2
}
# <worktree> <aside copy> <"mode blob">: succeeds when the copy set aside is
# what the index entry records. The type follows the mode (a symbolic link
# for 120000, a regular file otherwise); a link is compared by its whole
# target text, trailing newlines included, as git stores a link (the x after
# readlink keeps what $(...) would drop), and a regular file by its content
# hashed with the plan path's attributes and by its executable bit, unless
# core.fileMode is false, when git itself ignores that bit. A regular file
# holding a link's target text hashes like the link and is still no match.
amend_aside_matches() {
  local emode=${3%% *} eblob=${3#* } t
  if [ "$emode" = 120000 ]; then
    { [ -L "$2" ] && t=$(readlink -n -- "$2" && printf x); } || return 1
    [ "$(printf '%s' "${t%x}" | git -C "$1" hash-object --stdin 2>/dev/null)" = "$eblob" ]
    return
  fi
  { [ -f "$2" ] && [ ! -L "$2" ]; } || return 1
  [ "$(git -C "$1" hash-object --path="$rel" -- "$2" 2>/dev/null)" = "$eblob" ] || return 1
  [ "$(git -C "$1" config --bool core.fileMode 2>/dev/null)" != false ] || return 0
  if [ "$emode" = 100755 ]; then [ -x "$2" ]; else [ ! -x "$2" ]; fi
}
# <worktree> <old commit> <new commit>: one worktree's refresh through git's
# own two-way update, read-tree -m -u, which touches only the plan here and
# keeps the worktree's other changes. read-tree takes a missing file for an
# unchanged one and writes it back, so the plan file is first moved aside,
# with one rename onto a name this call created exclusively (never an
# earlier run's copy), checked there against its index entry, and only then
# is git asked to write the new plan into the empty path: a deletion made
# meanwhile fails the rename, and an edit fails the check. A failure moves
# the copy back with a hard link, which never replaces a file created at the
# path meanwhile; when one was, both are named. ln -P links a symbolic link
# itself, so a link comes back with its target byte for byte. A worktree whose index
# already holds the new plan (an earlier refresh that a crash cut short)
# needs no write, and is checked and updated in place.
amend_refresh_one() {
  local w=$1 p="$1/$rel" e aside why lt
  e=$(amend_wt_index "$w")
  [ -n "$e" ] || { amend_refresh_differs "$w"; return 1; }
  if [ "${e#* }" = "$(git -C "$w" rev-parse -q --verify "$3:$rel" 2>/dev/null)" ]; then
    amend_wt_plan_clean "$w" || { amend_refresh_differs "$w"; return 1; }
    git -C "$w" read-tree -m -u "$2" "$3" || { amend_refresh_settle "$w"; return 1; }
    return 0
  fi
  aside=$(mktemp "$(dirname "$p")/.$(basename "$p").sdd-amend-XXXXXX" 2>/dev/null) || { amend_refresh_differs "$w"; return 1; }
<content of <sw>/snippets/t2-e6b-seams.txt, lines 1-14: the amend-refresh-before-rename seam>
  if ! mv -f "$p" "$aside" 2>/dev/null; then rm -f "$aside"; amend_refresh_differs "$w"; return 1; fi
<content of <sw>/snippets/t2-e6b-seams.txt, lines 15-17: the amend-refresh-after-rename seam>
  why=differs
  if amend_aside_matches "$w" "$aside" "$e"; then
    if git -C "$w" read-tree -m -u "$2" "$3"; then rm -f "$aside"; return 0; fi
    why=settle
  fi
  if ln -P "$aside" "$p" 2>/dev/null; then
    rm -f "$aside"
    if [ "$why" = settle ]; then amend_refresh_settle "$w"; else amend_refresh_differs "$w"; fi
    return 1
  fi
  echo "sdd-state: the plan ref $ref carries the amendment, but the worktree $w could not be refreshed to it: a file appeared at $p while its copy was aside at $aside; keep the one you want at $p, then run the same amend again" >&2
  return 1
}
# <old commit> <new commit>: brings every worktree on the plan ref from the
# old commit's plan to the new one's, one worktree at a time
# (amend_refresh_one). A worktree that cannot be brought over is an error,
# never skipped: its index would keep the old plan staged against the new
# head; so is one whose directory has gone since the scan, and the record
# stays for the same amend run again. The index's stat data is refreshed
# first, or a file rewritten with the same content would be taken for an
# edit.
amend_refresh() {
  local i=0 w
  amend_ref_worktrees || { echo "sdd-state: the plan ref $ref carries the amendment, but the worktrees of $REPO could not be listed; run the same amend again" >&2; return 1; }
  while [ "$i" -lt "${#AMEND_WT[@]}" ]; do
    w=${AMEND_WT[$i]}
    if [ "${AMEND_WT_GONE[$i]}" != 0 ]; then amend_refresh_differs "$w"; return 1; fi
    i=$((i + 1))
    git -C "$w" update-index -q --refresh >/dev/null 2>&1
    amend_refresh_one "$w" "$1" "$2" || return 1
  done
}
````

The two `<content of ...>` lines are not literal: put the snippet's first fourteen lines (the comment and `case` block of `amend-refresh-before-rename`) where the first one stands, and its last three lines (the comment and `case` line of `amend-refresh-after-rename`) where the second stands, unchanged, so the seams are byte-for-byte the lines the red run used. The `amend_wt_plan_clean` helper and its comment stay; the dry run in `amend_wt_blocker` stays read-only.

- [ ] **Step 17: Run E6-b green**

```bash
bash <sw>/run-slices.sh <worktree> amend > <sw>/logs/t2-e6b.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 18: Docs and CHANGELOG for E6-b**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`amend\`'s worktree refresh moves the plan file aside and checks it there before git writes the new plan, so a deletion made during the refresh is no longer written back."
```

Expected: the two SDD pages refreshed, digests only.

- [ ] **Step 19: Commit E6-b**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t2-e6b.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t2-e6b.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t2-e6b.staged.diff
git -C <worktree> commit -m "fix(sdd-state): amend's refresh moves the plan file aside before git writes the new plan"
```

Expected: lint exit 0; `hits: 0`.

- [ ] **Step 20: Verify Task 2**

```bash
bash <sw>/run-slices.sh <worktree> amend > <sw>/logs/t2.slices.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t2` (changed script: `sdd-state`). Report the three red runs with their FAIL labels, and the exempt tests: the plain refresh (positive control), the executable-bit, earlier-aside and link-variant tests (guards that already refuse at e62fdb5, because `read-tree -m -u` refuses a mode or type change and an untracked dotfile is never touched), and the newline-target link test (a guard: at e62fdb5 `read-tree -m -u` compares the link itself, so the clean link takes the refresh).

### Task 3: Records, board, session ids

**Risk tier:** high — the record writers, the plain snapshot's new lock, and the session-id rule every writer checks: durable-record writers and locking.

**Depends on:** Task 2

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Test: `tests/sdd/test-sdd-state.sh`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`

**Interfaces:**
- Consumes: `record_publish <dir> <sid> <content>`, `write_activity <sid>`, `hp_lock`/`hp_unlock` (`sdd-common.sh:463`), `board_entries`, `merge_back_wait`.
- Produces: `sid_ok` also refuses whitespace and `:` (message `sdd-state: a session id must be one path entry without whitespace, a colon or control characters: %q`), and `cmd_register` calls it; `record_publish` publishes with one `rename(2)` through node; the seams `HYPERPOWERS_TEST_WRITER_AT=record-publish-after-check` and `HYPERPOWERS_TEST_PAUSE_AT=snapshot-plain-before-stamp` (pause files `$ROOT/.snapshot-plain-before-stamp-pause` and `-paused`), each touching the seam marker.

**Mirror:** `sdd-state:877` (the claim's `renameSync` one-liner) for E8-a; `sdd-state:446-453` (the branch path's locked stamp) and `sdd-state:355-359` (a pause seam) for E8-f; `tests/sdd/test-sdd-state.sh:3424-3429` (a paused writer polled from the test) for the E8-f tests.

- [ ] **Step 1: Check the host's session ids**

Run: `bash <sw>/sid-check.sh`
Expected: `lines=N bad=0` for some N. A non-zero `bad` means a ledger on this host holds a session id the widened rule refuses: stop and report it, because E8-d would strand that session.

**Finding E8-a, a directory swallows a record.**

- [ ] **Step 2: Write the E8-a test**

Write `<sw>/snippets/t3-e8a-test.sh`:

```bash
# A directory created at a record's path after record_publish's check: one rename(2) refuses it, where mv -f moved the record inside it and reported success.
rm -f "$TEST_ROOT/bd.rec.seam"
out=$(cd "$bd_a" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/bd.rec.seam" HYPERPOWERS_TEST_WRITER_AT=record-publish-after-check bash "$SDD_STATE" wait docs/plan.md --session srec --kind question --note record 2>"$TEST_ROOT/bd.rec.err"); rc=$?
if [ -f "$TEST_ROOT/bd.rec.seam" ] && [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ -d "$wsbd/waiting/srec" ] && [ -z "$(ls -A "$wsbd/waiting/srec")" ] && grep -qF "waiting/srec is not a regular file; refusing to replace it" "$TEST_ROOT/bd.rec.err"; then pass "a directory created at a record's path after the check refuses the publish and holds no record"; else fail "a directory created at a record's path after the check refuses the publish and holds no record (rc=$rc: $out: $(ls -A "$wsbd/waiting/srec" 2>/dev/null | tr '\n' ' '))"; fi
rm -rf "$wsbd/waiting/srec" "$wsbd/activity/srec"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED' <sw>/snippets/t3-e8a-test.sh`
Expected: exit 0.

- [ ] **Step 3: Run E8-a red**

Write `<sw>/snippets/t3-e8a-seam.txt`:

```bash
  # Test seam: HYPERPOWERS_TEST_WRITER_AT=record-publish-after-check makes a
  # directory at the destination after the check above, once.
  case "${HYPERPOWERS_TEST_WRITER_AT:-}" in record-publish-after-check) [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; mkdir "$dest"; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

```bash
bash <sw>/make-red.sh <worktree> t3-e8a
python3 <sw>/insert-at.py <sw>/red/t3-e8a/skills/subagent-driven-development/scripts/sdd-state after 'refusing to replace it" >&2; return 1; fi' <sw>/snippets/t3-e8a-seam.txt
bash <sw>/run-slices.sh <sw>/red/t3-e8a board > <sw>/logs/t3-e8a.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8a.red.log > <sw>/logs/t3-e8a.red.fails
```

Expected: exit 1; the fails list holds exactly "a directory created at a record's path after the check refuses the publish and holds no record" (at e62fdb5 the record lands inside the directory and `wait` answers `status=waiting`).

- [ ] **Step 4: Implement E8-a**

In `sdd-state`, with the Edit tool, replace

```text
# included, only the record's own directory is made, and an entry there
# that is not a regular file is refused: a rename onto a directory would
# move the record inside it and report success. The content goes to an
```

with

```text
# included, only the record's own directory is made, and an entry there
# that is not a regular file is refused. The record is published with one
# rename(2), through node's renameSync as claim publishes, which fails on a
# directory created after the check (mv -f moved the record inside it and
# reported success) and replaces a symbolic link rather than following it;
# the check stays for its message. The content goes to an
```

and replace

```text
  if [ -e "$dest" ] && [ ! -f "$dest" ]; then rm -f "$t"; echo "sdd-state: $dest is not a regular file; refusing to replace it" >&2; return 1; fi
  mv -f "$t" "$dest" || { rm -f "$t"; return 1; }
}
```

with

```text
  if [ -e "$dest" ] && [ ! -f "$dest" ]; then rm -f "$t"; echo "sdd-state: $dest is not a regular file; refusing to replace it" >&2; return 1; fi
<content of <sw>/snippets/t3-e8a-seam.txt>
  node -e 'const fs=require("fs");try{fs.renameSync(process.argv[1],process.argv[2]);}catch(e){process.exit(["EISDIR","ENOTEMPTY","EEXIST","ENOTDIR"].includes(e.code)?4:2);}' "$t" "$dest"; rc=$?
  [ "$rc" -ne 0 ] || return 0
  rm -f "$t"
  [ "$rc" -ne 4 ] || echo "sdd-state: $dest is not a regular file; refusing to replace it" >&2
  return 1
}
```

The `<content of ...>` line stands for the snippet's three lines, unchanged. Then change the function's first line `  local dest="$ROOT/$1/$2" t` to `  local dest="$ROOT/$1/$2" t rc`.

- [ ] **Step 5: Run E8-a green**

```bash
bash <sw>/run-slices.sh <worktree> claim register claim2 mergeback board > <sw>/logs/t3-e8a.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED` (the claim, register and merge-back slices write activity and waiting records through the new rename).

- [ ] **Step 6: Docs and CHANGELOG for E8-a**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "Waiting and activity records publish with one \`rename(2)\`, which refuses a directory created at the record's path rather than moving the record inside it."
```

Expected: the two SDD pages refreshed; neither describes how a record is renamed into place, so digests only.

- [ ] **Step 7: Commit E8-a**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8a.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8a.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8a.staged.diff
git -C <worktree> commit -m "fix(sdd-state): records publish with one rename(2) that refuses a directory"
```

Expected: lint exit 0; `hits: 0`.

**Finding E8-f, the plain snapshot's stamp.**

- [ ] **Step 8: Write the E8-f tests**

Write `<sw>/snippets/t3-e8f-test.sh`:

```bash
# A plain-backend snapshot --session stamps activity under the plan lock, as the branch path does, so a finish that removed the workspace while it waited for the lock is not undone. The control proves the lock is held at the stamp; the race holds the lock first and removes the workspace before releasing it.
rps="$TEST_ROOT/rps"; make_repo "$rps"; ensure "$rps" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
mkdir -p "$rps/docs"; printf '# P\n\n### Task 1: A\n' > "$rps/docs/plan.md"; git -C "$rps" add docs; git -C "$rps" commit -qm plan
wsrps=$(run_sdd_dir "$rps" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsrps/progress.md"
root_rps="$XDG_CACHE_HOME/hyperpowers/sdd/$(state_key "$rps")"; lock_rps="$STATE_ROOT/$(state_key "$rps").lock"
rm -f "$TEST_ROOT/rps.c.seam"; : > "$root_rps/.snapshot-plain-before-stamp-pause"
( cd "$rps" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/rps.c.seam" HYPERPOWERS_TEST_PAUSE_AT=snapshot-plain-before-stamp bash "$SDD_STATE" snapshot docs/plan.md --session srps > "$TEST_ROOT/rps.c.out" 2>/dev/null; echo "$?" > "$TEST_ROOT/rps.c.rc" ) &
n=0; while [ ! -e "$root_rps/.snapshot-plain-before-stamp-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
rps_held=0; [ -d "$lock_rps" ] && rps_held=1
rm -f "$root_rps/.snapshot-plain-before-stamp-pause"; wait
if [ -f "$TEST_ROOT/rps.c.seam" ] && [ "$rps_held" = 1 ] && [ "$(cat "$TEST_ROOT/rps.c.rc")" = 0 ] && [ "$(cat "$TEST_ROOT/rps.c.out")" = "status=plain" ] && [ -f "$wsrps/activity/srps" ]; then pass "a plain-backend snapshot --session holds the plan lock while it stamps activity"; else fail "a plain-backend snapshot --session holds the plan lock while it stamps activity (held=$rps_held rc=$(cat "$TEST_ROOT/rps.c.rc"): $(cat "$TEST_ROOT/rps.c.out"))"; fi
: > "$root_rps/.snapshot-plain-before-stamp-pause"; rm -f "$TEST_ROOT/rps.held" "$TEST_ROOT/rps.go" "$TEST_ROOT/rps.done"
bash -c '. "$1"; hp_lock "$2" || exit 2; : > "$3.held"; while [ ! -e "$3.go" ]; do sleep 0.1; done; rm -rf "$4"; hp_unlock; : > "$3.done"' _ "$LIB" "$rps" "$TEST_ROOT/rps" "$wsrps" &
n=0; while [ ! -e "$TEST_ROOT/rps.held" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
( cd "$rps" && HYPERPOWERS_TEST_PAUSE_AT=snapshot-plain-before-stamp bash "$SDD_STATE" snapshot docs/plan.md --session srps > "$TEST_ROOT/rps.out" 2>/dev/null; echo "$?" > "$TEST_ROOT/rps.rc" ) &
n=0; while [ ! -e "$root_rps/.snapshot-plain-before-stamp-paused" ] && [ "$n" -lt 20 ]; do sleep 0.1; n=$((n + 1)); done
: > "$TEST_ROOT/rps.go"
n=0; while [ ! -e "$TEST_ROOT/rps.done" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
rm -f "$root_rps/.snapshot-plain-before-stamp-pause"; wait
if [ -e "$TEST_ROOT/rps.done" ] && [ ! -e "$wsrps" ]; then pass "a plain-backend snapshot --session that waited on a finish's lock recreates no workspace"; else fail "a plain-backend snapshot --session that waited on a finish's lock recreates no workspace (rc=$(cat "$TEST_ROOT/rps.rc" 2>/dev/null): $(cat "$TEST_ROOT/rps.out" 2>/dev/null); $(ls -A "$wsrps" 2>/dev/null | tr '\n' ' '))"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'pass "snapshot under the plain backend reports plain"' <sw>/snippets/t3-e8f-test.sh`
Expected: exit 0.

- [ ] **Step 9: Run E8-f red**

The red tree gets the pause seam alone, in today's unlocked stamp. Write `<sw>/snippets/t3-e8f-redseam.txt`:

```bash
    if [ -n "$sid" ] && [ -f "$WSDIR/progress.md" ]; then
      if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = snapshot-plain-before-stamp ]; then
        [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
        : > "$ROOT/.snapshot-plain-before-stamp-paused"
        while [ -e "$ROOT/.snapshot-plain-before-stamp-pause" ]; do sleep 0.1; done
        rm -f "$ROOT/.snapshot-plain-before-stamp-paused"
      fi
      write_activity "$sid" || { echo "status=error"; return 2; }
    fi
```

```bash
bash <sw>/make-red.sh <worktree> t3-e8f
python3 <sw>/insert-at.py <sw>/red/t3-e8f/skills/subagent-driven-development/scripts/sdd-state replace 'then write_activity "$sid" || { echo "status=error"; return 2; }; fi' <sw>/snippets/t3-e8f-redseam.txt
bash <sw>/run-slices.sh <sw>/red/t3-e8f plainfix snapshot > <sw>/logs/t3-e8f.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8f.red.log > <sw>/logs/t3-e8f.red.fails
```

Expected: exit 1; the fails list holds exactly the two E8-f labels: at e62fdb5 no lock is held at the stamp, and the paused stamp lands after the holder removed the workspace, recreating it.

- [ ] **Step 10: Implement E8-f**

In `cmd_snapshot`, with the Edit tool, replace

```text
  # The plain backend commits nothing, but the board still reads the
  # activity stamp from the local workspace.
  if [ "$BACKEND" != branch ]; then
    if [ -n "$sid" ] && [ -f "$WSDIR/progress.md" ]; then write_activity "$sid" || { echo "status=error"; return 2; }; fi
    echo "status=plain"; return 0
  fi
```

with

```text
  # The plain backend commits nothing, but the board still reads the
  # activity stamp from the local workspace. The stamp is written under the
  # plan lock, as on the branch path, and the ledger is checked under it, so
  # a finish that removed the workspace while this call waited for the lock
  # does not have it recreated by the stamp's mkdir.
  if [ "$BACKEND" != branch ]; then
    if [ -n "$sid" ]; then
      hp_lock "$PLAN_DIR" || { echo "status=error"; return 2; }
      if [ -f "$WSDIR/progress.md" ]; then
        # Test seam: HYPERPOWERS_TEST_PAUSE_AT=snapshot-plain-before-stamp
        # pauses under the lock, before the stamp, while
        # $ROOT/.snapshot-plain-before-stamp-pause exists.
        if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = snapshot-plain-before-stamp ]; then
          [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"
          : > "$ROOT/.snapshot-plain-before-stamp-paused"
          while [ -e "$ROOT/.snapshot-plain-before-stamp-pause" ]; do sleep 0.1; done
          rm -f "$ROOT/.snapshot-plain-before-stamp-paused"
        fi
        write_activity "$sid" || { hp_unlock; echo "status=error"; return 2; }
      fi
      hp_unlock
    fi
    echo "status=plain"; return 0
  fi
```

- [ ] **Step 11: Run E8-f green**

```bash
bash <sw>/run-slices.sh <worktree> plainfix snapshot > <sw>/logs/t3-e8f.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 12: Docs and CHANGELOG for E8-f**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "A plain-backend \`snapshot --session\` stamps activity under the plan lock, so it cannot recreate a workspace a finish removed meanwhile."
```

Expected: the two SDD pages refreshed, digests only.

- [ ] **Step 13: Commit E8-f**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8f.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8f.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8f.staged.diff
git -C <worktree> commit -m "fix(sdd-state): the plain snapshot stamps activity under the plan lock"
```

Expected: lint exit 0; `hits: 0`.

**Finding E8-g, an empty `--session`.**

- [ ] **Step 14: Write the E8-g test**

Write `<sw>/snippets/t3-e8g-test.sh`:

```bash
out=$(run_state "$s1" snapshot docs/plan.md --session '' 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ]; then pass "snapshot refuses an empty --session"; else fail "snapshot refuses an empty --session (rc=$rc: $out)"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'waited on a finish' <sw>/snippets/t3-e8g-test.sh`
Expected: exit 0 (the needle is the E8-f race test's line).

- [ ] **Step 15: Run E8-g red**

```bash
bash <sw>/make-red.sh <worktree> t3-e8g
bash <sw>/run-slices.sh <sw>/red/t3-e8g plainfix snapshot > <sw>/logs/t3-e8g.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8g.red.log > <sw>/logs/t3-e8g.red.fails
```

Expected: exit 1; the fails list holds "snapshot refuses an empty --session" (at e62fdb5 the empty id skips the check and the snapshot runs) and the E8-f control label, whose seam this red tree lacks; the E8-f race label may pass here, since without the seam the stamp lands before the holder removes the workspace.

- [ ] **Step 16: Implement E8-g**

In `cmd_snapshot`, with the Edit tool, replace

```text
  local plan="" msg="" sid="" code="" out rc n
  while [ $# -gt 0 ]; do
    case "$1" in
      -m) [ $# -ge 2 ] || usage; msg=$2; shift 2 ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
```

with

```text
  local plan="" msg="" sid="" sid_given=0 code="" out rc n
  while [ $# -gt 0 ]; do
    case "$1" in
      -m) [ $# -ge 2 ] || usage; msg=$2; shift 2 ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; sid_given=1; shift 2 ;;
```

and replace

```text
  [ -z "$sid" ] || sid_ok "$sid" || { echo "status=error"; return 2; }
  resolve_plan "$plan"
  code_repo_check "$code" "$WSDIR/progress.md" || return $?
```

with

```text
  # A given --session is checked whatever its value: an empty one is no
  # session id, not the absence of one.
  [ "$sid_given" -eq 0 ] || sid_ok "$sid" || { echo "status=error"; return 2; }
  resolve_plan "$plan"
  code_repo_check "$code" "$WSDIR/progress.md" || return $?
```

- [ ] **Step 17: Run E8-g green**

```bash
bash <sw>/run-slices.sh <worktree> plainfix snapshot > <sw>/logs/t3-e8g.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 18: Docs, CHANGELOG and commit for E8-g**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`snapshot --session ''\` is refused like any other invalid session id."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8g.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8g.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8g.staged.diff
git -C <worktree> commit -m "fix(sdd-state): snapshot refuses an empty --session"
```

Expected: the two SDD pages refreshed (digests only); lint exit 0; `hits: 0`.

**Finding E8-d, whitespace and colons in a session id.**

- [ ] **Step 19: Write the E8-d test**

Write `<sw>/snippets/t3-e8d-test.sh`:

```bash
# A session id holding whitespace or a colon would split the ledger's session line and the board's parse of it: register and wait refuse it before writing anything.
for sid_bad in 'a b' 'x: mode y'; do
  out1=$(run_state "$bd_a" register docs/plan.md --session "$sid_bad" --integration feat 2>"$TEST_ROOT/bd.sid.err"); rc1=$?
  out2=$(run_state "$bd_a" wait docs/plan.md --session "$sid_bad" --kind question --note sid 2>>"$TEST_ROOT/bd.sid.err"); rc2=$?
  if [ "$rc1" -eq 2 ] && [ "$out1" = "status=error" ] && [ "$rc2" -eq 2 ] && [ "$out2" = "status=error" ] && [ "$(grep -c 'a session id must be one path entry without whitespace, a colon or control characters' "$TEST_ROOT/bd.sid.err")" = 2 ] && [ ! -e "$wsbd/waiting/$sid_bad" ] && [ ! -e "$wsbd/activity/$sid_bad" ]; then pass "register and wait refuse the session id '$sid_bad'"; else fail "register and wait refuse the session id '$sid_bad' (register rc=$rc1: $out1; wait rc=$rc2: $out2: $(tr '\n' '|' < "$TEST_ROOT/bd.sid.err"))"; fi
done
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED' <sw>/snippets/t3-e8d-test.sh`
Expected: exit 0 (the block lands after the E8-a test).

- [ ] **Step 20: Run E8-d red**

```bash
bash <sw>/make-red.sh <worktree> t3-e8d
bash <sw>/run-slices.sh <sw>/red/t3-e8d board > <sw>/logs/t3-e8d.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8d.red.log > <sw>/logs/t3-e8d.red.fails
```

Expected: exit 1; the fails list holds both "register and wait refuse the session id ..." labels (at e62fdb5 `register` checks no id and `wait` accepts both) and the E8-a label, whose seam this red tree lacks.

- [ ] **Step 21: Implement E8-d**

In `sdd-state`, with the Edit tool, replace

```text
# owner record, the lease and amend's ledger line into lines of their own.
# Every subcommand that writes the id calls this before its first side
# effect.
sid_ok() {
  case "$1" in
    ''|.|..|*/*|*[[:cntrl:]]*) printf 'sdd-state: a session id must be one path entry without control characters: %q\n' "$1" >&2; return 1 ;;
  esac
}
```

with

```text
# owner record, the lease and amend's ledger line into lines of their own.
# Whitespace or a colon would split the ledger's session line and the
# board's parse of it, which reads the id up to the first ": mode ".
# Every subcommand that writes the id calls this before its first side
# effect.
sid_ok() {
  case "$1" in
    ''|.|..|*/*|*[[:cntrl:]]*|*[[:space:]]*|*:*) printf 'sdd-state: a session id must be one path entry without whitespace, a colon or control characters: %q\n' "$1" >&2; return 1 ;;
  esac
}
```

and in `cmd_register` replace

```text
  [ -n "$plan" ] && [ -n "$sid" ] && [ -n "$integration" ] || usage
  resolve_plan "$plan"
  ledger=$(ledger_path)
```

with

```text
  [ -n "$plan" ] && [ -n "$sid" ] && [ -n "$integration" ] || usage
  sid_ok "$sid" || { echo "status=error"; return 2; }
  resolve_plan "$plan"
  ledger=$(ledger_path)
```

No test matches the old sentence whole: the merge-back entry test (`test-sdd-state.sh:4660` at plan time) greps `a session id must be one path entry`, which the new message keeps, and the handback and tracked-job tests that pass ids with spaces check other refusals.

- [ ] **Step 22: Run E8-d green**

```bash
bash <sw>/run-slices.sh <worktree> plainfix snapshot register claim2 mergeback board > <sw>/logs/t3-e8d.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 23: Docs, CHANGELOG and commit for E8-d**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "Session ids may not hold whitespace or a colon, which would split the ledger's session line; \`register\` now checks the id too."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8d.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8d.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8d.staged.diff
git -C <worktree> commit -m "fix(sdd-state): session ids exclude whitespace and colons, and register checks them"
```

Expected: the two SDD pages refreshed. Re-read sdd-internals' session-line paragraph: at plan time it names no rule for the id's characters, so digests only. Lint exit 0; `hits: 0`.

**Finding E8-b, phantom sessions from fetched names.**

- [ ] **Step 24: Write the E8-b test**

Write `<sw>/snippets/t3-e8b-test.sh`:

```bash
# A waiting entry whose name holds a newline, as a fetched state branch can carry, is no session id: the board skips it instead of printing a row for each line of its name.
mkdir -p "$wsbd/waiting"; printf 'session=a\n' > "$wsbd/waiting/"$'a\nb'
out=$(run_state "$bd_a" board docs/plan.md 2>"$TEST_ROOT/bd.phantom.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -cE '^session (a|b) ')" = 0 ] && grep -qF 'a session id must be one path entry' "$TEST_ROOT/bd.phantom.err"; then pass "a waiting entry whose name holds a newline shows no phantom sessions on the board"; else fail "a waiting entry whose name holds a newline shows no phantom sessions on the board (rc=$rc: $(printf '%s\n' "$out" | grep -E '^session (a|b) ' | tr '\n' '|'))"; fi
rm -f "$wsbd/waiting/"$'a\nb'
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'if [ "$failures" -gt 0 ]; then echo "STATUS: FAILED' <sw>/snippets/t3-e8b-test.sh`
Expected: exit 0.

- [ ] **Step 25: Run E8-b red**

```bash
bash <sw>/make-red.sh <worktree> t3-e8b
bash <sw>/run-slices.sh <sw>/red/t3-e8b board > <sw>/logs/t3-e8b.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8b.red.log > <sw>/logs/t3-e8b.red.fails
```

Expected: exit 1; the fails list holds "a waiting entry whose name holds a newline shows no phantom sessions on the board" (at e62fdb5 the name prints as two lines and each becomes a session row), plus the E8-a and E8-d labels.

- [ ] **Step 26: Implement E8-b**

In `board_entries`, with the Edit tool, replace

```text
# <dir> [f] -> the name of every entry in it (with f, every regular file),
# dot names included. record_publish makes its temporary files outside the
# tracked tree, so every name in waiting/ or activity/ is a session's
# record, and a session id may begin with a dot.
board_entries() {
  local f
  for f in "$1"/* "$1"/.*; do
    case "${f##*/}" in .|..) continue ;; esac
    if [ "${2:-}" = f ]; then [ -f "$f" ] || continue; else [ -e "$f" ] || continue; fi
    printf '%s\n' "${f##*/}"
```

with

```text
# <dir> [f] -> the name of every entry in it that is a session id (with f,
# every such regular file), dot names included. record_publish makes its
# temporary files outside the tracked tree, so every such name in waiting/
# or activity/ is a session's record, and a session id may begin with a dot.
board_entries() {
  local f
  for f in "$1"/* "$1"/.*; do
    case "${f##*/}" in .|..) continue ;; esac
    if [ "${2:-}" = f ]; then [ -f "$f" ] || continue; else [ -e "$f" ] || continue; fi
    # These directories arrive with a fetched state branch: a name that is
    # no session id, one holding a newline above all, would print as
    # phantom sessions in this one-name-per-line listing.
    sid_ok "${f##*/}" || continue
    printf '%s\n' "${f##*/}"
```

- [ ] **Step 27: Run E8-b green**

```bash
bash <sw>/run-slices.sh <worktree> board > <sw>/logs/t3-e8b.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 28: Docs, CHANGELOG and commit for E8-b**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "The board skips \`waiting/\` and \`activity/\` entries whose names are not session ids, so a fetched name holding a newline shows no phantom sessions."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8b.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8b.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8b.staged.diff
git -C <worktree> commit -m "fix(sdd-state): the board skips waiting and activity entries that are not session ids"
```

Expected: the two SDD pages refreshed, digests only; lint exit 0; `hits: 0`.

**Finding E8-e, a merge-back conflict's activity.**

- [ ] **Step 29: Write the E8-e tests**

Write `<sw>/snippets/t3-e8e-seed.sh`:

```bash
mkdir -p "$wsmb/activity"; printf '2026-01-01T00:00:00Z\n' > "$wsmb/activity/s1"
```

Write `<sw>/snippets/t3-e8e-test.sh`:

```bash
# A merge-back that stops on a conflict stamps the session's activity beside its waiting record, as wait does; a stamp that cannot be written is an error that still names the conflict.
st_mb=$(cat "$wsmb/activity/s1" 2>/dev/null)
if [ -n "$st_mb" ] && [ "$st_mb" != "2026-01-01T00:00:00Z" ]; then pass "a merge-back conflict stamps the session's activity"; else fail "a merge-back conflict stamps the session's activity (stamp: $st_mb)"; fi
rm -f "$wsmb/activity/s1" "$wsmb/waiting/s1"; mkdir "$wsmb/activity/s1"
out=$(run_state "$mb_a" merge-back docs/plan.md 3 --session s1 --commit "$t3" 2>"$TEST_ROOT/mb.act.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qxF "sdd-state: merging ${t3:0:7} into feat conflicts in src/a.txt, and the waiting record was written, but the activity stamp could not be" "$TEST_ROOT/mb.act.err" && [ "$(sed -n 's/^kind=//p' "$wsmb/waiting/s1")" = merge ] && [ "$(git -C "$mb_a" log -1 --format=%s feat)" = "stranger edit" ]; then pass "a conflict whose activity stamp cannot be written is an error naming the conflict, with the waiting record written"; else fail "a conflict whose activity stamp cannot be written is an error naming the conflict, with the waiting record written (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/mb.act.err"))"; fi
rmdir "$wsmb/activity/s1"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'pts_mb=$(date -u' <sw>/snippets/t3-e8e-seed.sh
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'pass "a conflict moves no ref and posts a merge waiting record"' <sw>/snippets/t3-e8e-test.sh
```

Expected: both exit 0. The stop-guard test that follows reads `waiting/s1` again; the second merge-back rewrote it after `pts_mb`, so it still reads as this turn's.

- [ ] **Step 30: Run E8-e red**

```bash
bash <sw>/make-red.sh <worktree> t3-e8e
bash <sw>/run-slices.sh <sw>/red/t3-e8e mergeback > <sw>/logs/t3-e8e.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t3-e8e.red.log > <sw>/logs/t3-e8e.red.fails
```

Expected: exit 1; the fails list holds exactly the two E8-e labels (at e62fdb5 the conflict path writes no stamp, and the second call answers `status=conflict`).

- [ ] **Step 31: Implement E8-e**

In `cmd_merge_back`, with the Edit tool, replace

```text
        merge_back_wait "$paths" || { hp_unlock; echo "sdd-state: merging ${sha:0:7} into $integ conflicts in $paths, but the waiting record could not be written" >&2; echo "status=error"; return 2; }
        hp_unlock; echo "status=conflict task=$n paths=$paths"; return 8
```

with

```text
        merge_back_wait "$paths" || { hp_unlock; echo "sdd-state: merging ${sha:0:7} into $integ conflicts in $paths, but the waiting record could not be written" >&2; echo "status=error"; return 2; }
        # A session stopped on a conflict is alive, as one that ran wait is:
        # the stamp beside the record keeps the board from reading it idle.
        write_activity "$sid" || { hp_unlock; echo "sdd-state: merging ${sha:0:7} into $integ conflicts in $paths, and the waiting record was written, but the activity stamp could not be" >&2; echo "status=error"; return 2; }
        hp_unlock; echo "status=conflict task=$n paths=$paths"; return 8
```

- [ ] **Step 32: Run E8-e green**

```bash
bash <sw>/run-slices.sh <worktree> mergeback > <sw>/logs/t3-e8e.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 33: Docs, CHANGELOG and commit for E8-e**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "A merge-back that stops on a conflict stamps the session's activity beside its waiting record, as \`wait\` does."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t3-e8e.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t3-e8e.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t3-e8e.staged.diff
git -C <worktree> commit -m "fix(sdd-state): a merge-back conflict stamps the session's activity"
```

Expected: the two SDD pages refreshed, digests only; lint exit 0; `hits: 0`.

- [ ] **Step 34: Verify Task 3**

```bash
bash <sw>/run-slices.sh <worktree> plainfix snapshot register claim2 mergeback board > <sw>/logs/t3.slices.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t3` (changed script: `sdd-state`). Report the six red runs with their FAIL labels and the `sid-check.sh` line; no exempt tests in this task.

### Task 4: Raw objects, symbolic refs, approval line

**Risk tier:** high — merge-back's approval check and its ref swap decide what reaches the integration branch: approval-authority code.

**Depends on:** Task 3

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Modify: `skills/subagent-driven-development/scripts/review-package`
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/example-workflow.md`
- Test: `tests/sdd/test-sdd-state.sh`
- Test: `tests/claude-code/test-sdd-dir-path.sh`
- Test: `tests/sdd/test-sdd-contract.sh`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`
- Modify (digest only, through the SDD SKILL.md source): `docs/site/recommended-settings.md`, `docs/site/advanced/codex-gates.md`, `docs/site/advanced/triggering.md`, `docs/site/advanced/decision-records.md`, `docs/site/skills/communication.md`, `docs/site/skills/using-hyperpowers.md`, `docs/site/skills/executing-plans.md`, `docs/site/skills/writing-plans.md`, `docs/site/skills/finishing-a-development-branch.md`, `docs/site/skills/test-driven-development.md`, `docs/site/skills/requesting-code-review.md`, `docs/site/skills/receiving-code-review.md`, `docs/site/skills/using-git-worktrees.md`

**Interfaces:**
- Consumes: `ledger_records` (`sdd-state:465`), `cmd_merge_back`'s scope (`code`, `ref` = `refs/heads/<integ>`, `sha` the full id, `n`, `WSDIR`), `cmd_amend`'s attempt loop.
- Produces: the approval line `Task <N>: approved <full id>`, read only from complete records and compared whole, as wide as the repository's ids (40 or 64); `merge-back` and `amend` refuse a symbolic ref (exit 2, `status=error`) and swap with `update-ref --no-deref`; `review-package` and `merge-back` run git without replace refs or grafts. Seams: `HYPERPOWERS_TEST_WRITER_AT=merge-back-symref-before-swap:<branch>` and `amend-symref-before-swap:<branch>`, each touching the seam marker. Task 6's skill-text edits come after this task's approval-bullet change, and the evidence note's line numbers count it.

**Mirror:** `sdd-state:2390-2393` (the existing `local -x GIT_NO_REPLACE_OBJECTS=1`); `tests/sdd/test-sdd-state.sh:4639-4650` (Task 8, the replace-ref merge-back test) for Tasks 10 and 11; `tests/claude-code/test-sdd-dir-path.sh:537-567` (the review-package range tests).

The spec sets `GIT_GRAFT_FILE=/dev/null` (spec lines 317-318). Probed with git 2.56.0 on 2026-11-09, that value does disable `info/grafts`, but every git call that reads a commit then prints git's eight-line `hint: Support for <GIT_DIR>/info/grafts is deprecated` advice on stderr, whether or not a graft file exists, so each merge-back and package would carry it. A path that can never exist, `GIT_GRAFT_FILE=/dev/null/no-grafts` (a path under a device file fails with `ENOTDIR`), disables grafts with no output; the plan uses it, and the tests assert the hint is absent.

**Finding E7-a and E7-c, replace objects and grafts.**

- [ ] **Step 1: Write the review-package tests**

Write `<sw>/snippets/t4-e7ac-pkg.sh`:

```bash

echo ""
echo "Test: review-package reads the objects as they were written, without replace refs or grafts"
raw="$TEST_ROOT/repo-raw"; make_repo "$raw"
mkdir -p "$raw/docs"; echo plan > "$raw/docs/plan.md"; git -C "$raw" add -A; git -C "$raw" commit -qm base
raw_base=$(git -C "$raw" rev-parse HEAD)
printf 'first\n' > "$raw/one.txt"; git -C "$raw" add -A; git -C "$raw" commit -qm "raw work one"
raw_one=$(git -C "$raw" rev-parse HEAD)
printf 'second\n' > "$raw/two.txt"; git -C "$raw" add -A; git -C "$raw" commit -qm "raw work two"
raw_head=$(git -C "$raw" rev-parse HEAD)
raw_tree=$( { git -C "$raw" ls-tree "$raw_head"; printf '100644 blob %s\tunreviewed.txt\n' "$(printf 'unreviewed\n' | git -C "$raw" hash-object -w --stdin)"; } | git -C "$raw" mktree)
git -C "$raw" replace "$raw_head" "$(git -C "$raw" commit-tree "$raw_tree" -p "$raw_one" -m "raw work two")"
rc=0
( cd "$raw" && bash "$REVIEW_PACKAGE" docs/plan.md "$raw_base" "$raw_head" "$TEST_ROOT/raw-replace.diff" ) >/dev/null 2>"$TEST_ROOT/raw-replace.err" || rc=$?
if [ "$rc" -eq 0 ] && grep -q '^+second$' "$TEST_ROOT/raw-replace.diff" && ! grep -q unreviewed "$TEST_ROOT/raw-replace.diff" && ! grep -q 'grafts is deprecated' "$TEST_ROOT/raw-replace.err"; then pass "a replace ref on the head does not change the package"; else fail "a replace ref on the head does not change the package (rc=$rc)"; fi
git -C "$raw" replace -d "$raw_head" >/dev/null
mkdir -p "$raw/.git/info"; printf '%s %s\n' "$raw_head" "$raw_base" > "$raw/.git/info/grafts"
rc=0
( cd "$raw" && bash "$REVIEW_PACKAGE" docs/plan.md "$raw_base" "$raw_head" "$TEST_ROOT/raw-graft.diff" ) >/dev/null 2>"$TEST_ROOT/raw-graft.err" || rc=$?
rm -f "$raw/.git/info/grafts"
if [ "$rc" -eq 0 ] && grep -q ' raw work one$' "$TEST_ROOT/raw-graft.diff" && grep -q ' raw work two$' "$TEST_ROOT/raw-graft.diff" && grep -q '^+first$' "$TEST_ROOT/raw-graft.diff" && ! grep -q 'grafts is deprecated' "$TEST_ROOT/raw-graft.err"; then pass "a graft on the head does not hide commits from the package"; else fail "a graft on the head does not hide commits from the package (rc=$rc)"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/claude-code/test-sdd-dir-path.sh after 'pass "a real range still produces a package"' <sw>/snippets/t4-e7ac-pkg.sh`
Expected: exit 0.

- [ ] **Step 2: Write the merge-back graft test**

Write `<sw>/snippets/t4-e7ac-mb.sh`:

```bash
# A graft cannot fake ancestry for merge-back: an info/grafts entry that makes the approved commit a child of the integration head would turn a divergent merge into a fast forward and drop the integration-only commit.
printf '\n### Task 10: G\n\n**Risk tier:** standard\n\n**Depends on:** none\n' >> "$mb_a/docs/plan2.md"; git -C "$mb_a" switch -q feat; git -C "$mb_a" commit -qam "plan2 task 10"; git -C "$mb_a" switch -q --detach feat
run_state "$mb_a" claim docs/plan2.md 10 --session s3 >/dev/null; git -C "$mb_a" switch -q "feat.$ws8mb2.task-10"; printf 'g\n' > "$mb_a/src/g.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm g; g1=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
git -C "$mb_a" switch -q feat; printf 'integration only\n' > "$mb_a/src/io.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm "integration only"; hg=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 10: approved %s\n' "${g1:0:7}" >> "$wsmb2/progress.md"
mkdir -p "$mb_a/.git/info"; printf '%s %s\n' "$g1" "$hg" > "$mb_a/.git/info/grafts"
out=$(run_state "$mb_a" merge-back docs/plan2.md 10 --session s3 --commit "$g1" 2>"$TEST_ROOT/mb.graft.err"); rc=$?
rm -f "$mb_a/.git/info/grafts"; hm10=$(git -C "$mb_a" rev-parse feat)
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=10 head=${hm10:0:7}" ] && [ "$(git -C "$mb_a" rev-parse "$hm10^1")" = "$hg" ] && [ "$(git -C "$mb_a" rev-parse "$hm10^2" 2>/dev/null)" = "$g1" ] && [ "$(git -C "$mb_a" show "$hm10:src/io.txt" 2>/dev/null)" = "integration only" ] && ! grep -q 'grafts is deprecated' "$TEST_ROOT/mb.graft.err"; then pass "a graft cannot fake ancestry for merge-back: a divergent merge keeps both parents and the integration-only content"; else fail "a graft cannot fake ancestry for merge-back: a divergent merge keeps both parents and the integration-only content (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/mb.graft.err"))"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'merge-back refuses a slash-bearing session id at its entry, before the merge"; else' <sw>/snippets/t4-e7ac-mb.sh`
Expected: exit 0.

- [ ] **Step 3: Run E7-a/c red**

```bash
bash <sw>/make-red.sh <worktree> t4-e7ac
bash <sw>/red/t4-e7ac/tests/claude-code/test-sdd-dir-path.sh > <sw>/logs/t4-e7ac.red.pkg.log 2>&1
bash <sw>/run-slices.sh <sw>/red/t4-e7ac mergeback > <sw>/logs/t4-e7ac.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t4-e7ac.red.pkg.log > <sw>/logs/t4-e7ac.red.pkg.fails
grep -F '[FAIL]' <sw>/logs/t4-e7ac.red.log > <sw>/logs/t4-e7ac.red.fails
```

Expected: both runs exit 1. `t4-e7ac.red.pkg.fails` holds exactly "a replace ref on the head does not change the package" (at e62fdb5 the package shows `unreviewed.txt`) and "a graft on the head does not hide commits from the package" (the graft drops `raw work one` from the commit list; the tree diff is the same either way, so the commit list is what fails). `t4-e7ac.red.fails` holds the Task 10 label (at e62fdb5 the graft makes the merge a fast forward to `g1`, and `src/io.txt` is gone from the head) and the two E8-e labels, whose fix (Task 3) the red tree lacks; nothing else.

- [ ] **Step 4: Implement E7-a/c**

In `review-package`, with the Edit tool, replace

```text
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

with

```text
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The package is what reviewers approve, so every git call reads the objects
# as they were written: a replace ref would show another commit's tree under
# the head's id, and an info/grafts entry would hide commits from the list.
# GIT_GRAFT_FILE names a path that can never exist: /dev/null also disables
# grafts, but makes git print its graft-deprecation advice on every call.
export GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/no-grafts
```

In `cmd_merge_back`, replace

```text
  # A replace ref would have git read another commit's parents and tree under
  # the approved id, and merge content nobody reviewed: every git call here,
  # and in the helpers it calls, reads the objects as they were written.
  local -x GIT_NO_REPLACE_OBJECTS=1
```

with

```text
  # A replace ref would have git read another commit's parents and tree under
  # the approved id, and merge content nobody reviewed; an info/grafts entry
  # would fake ancestry and turn a divergent merge into a fast forward that
  # drops the integration branch's own commits. Every git call here, and in
  # the helpers it calls, reads the objects as they were written.
  # GIT_GRAFT_FILE names a path that can never exist: /dev/null also disables
  # grafts, but makes git print its graft-deprecation advice on every call.
  local -x GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null/no-grafts
```

- [ ] **Step 5: Run E7-a/c green**

```bash
bash <worktree>/tests/claude-code/test-sdd-dir-path.sh > <sw>/logs/t4-e7ac.green.pkg.log 2>&1
bash <sw>/run-slices.sh <worktree> mergeback > <sw>/logs/t4-e7ac.green.log 2>&1
```

Expected: both exit 0 (`echo $?`); the slice log ends `STATUS: PASSED`, the package log has no `[FAIL]` line.

- [ ] **Step 6: Docs and CHANGELOG for E7-a/c**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`review-package\` reads the objects as written, ignoring replace refs and grafts, and merge-back ignores grafts too, so reviewers see what merges and a graft cannot turn a divergent merge into a fast forward."
```

Expected: the two SDD pages refreshed. sdd-internals' review-package bullet (`:72`) says what the package holds, which is unchanged, so digests only.

- [ ] **Step 7: Commit E7-a/c**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash -n <worktree>/skills/subagent-driven-development/scripts/review-package
bash -n <worktree>/tests/claude-code/test-sdd-dir-path.sh
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state <worktree>/skills/subagent-driven-development/scripts/review-package <worktree>/tests/claude-code/test-sdd-dir-path.sh > <sw>/logs/t4-e7ac.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/review-package tests/sdd/test-sdd-state.sh tests/claude-code/test-sdd-dir-path.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t4-e7ac.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t4-e7ac.staged.diff
git -C <worktree> commit -m "fix(sdd): review-package and merge-back read raw objects without replace refs or grafts"
```

Expected: lint exit 0; `hits: 0`.

**Finding E7-d, symbolic refs.**

- [ ] **Step 8: Write the E7-d tests**

Write `<sw>/snippets/t4-e7d-mb.sh`:

```bash
# A symbolic integration ref: merge-back refuses one, and its swap never writes through one made symbolic after that check, so the branch it points to never moves.
printf '\n### Task 11: Y\n\n**Risk tier:** standard\n\n**Depends on:** none\n' >> "$mb_a/docs/plan2.md"; git -C "$mb_a" switch -q feat; git -C "$mb_a" commit -qam "plan2 task 11"; git -C "$mb_a" switch -q --detach feat
run_state "$mb_a" claim docs/plan2.md 11 --session s3 >/dev/null; git -C "$mb_a" switch -q "feat.$ws8mb2.task-11"; printf 'y\n' > "$mb_a/src/y.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm y; y11=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 11: approved %s\n' "${y11:0:7}" >> "$wsmb2/progress.md"
h11=$(git -C "$mb_a" rev-parse feat); git -C "$mb_a" update-ref refs/heads/mb-other "$h11"; git -C "$mb_a" symbolic-ref refs/heads/feat refs/heads/mb-other
lg_mbsym=$(cksum < "$wsmb2/progress.md")
out=$(run_state "$mb_a" merge-back docs/plan2.md 11 --session s3 --commit "$y11" 2>"$TEST_ROOT/mb.sym.err"); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qF "the integration branch feat is a symbolic ref; merge-back writes only a branch that holds a commit" "$TEST_ROOT/mb.sym.err" && [ "$(git -C "$mb_a" rev-parse mb-other)" = "$h11" ] && [ "$(cksum < "$wsmb2/progress.md")" = "$lg_mbsym" ] && [ ! -e "$wsmb2/merges/task-11" ]; then pass "merge-back refuses a symbolic integration ref and leaves the branch it points to unmoved"; else fail "merge-back refuses a symbolic integration ref and leaves the branch it points to unmoved (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/mb.sym.err"))"; fi
git -C "$mb_a" update-ref --no-deref refs/heads/feat "$h11"; git -C "$mb_a" update-ref refs/heads/mb-other "$h11"
rm -f "$TEST_ROOT/mb.sym.seam"
out=$(cd "$mb_a" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/mb.sym.seam" HYPERPOWERS_TEST_WRITER_AT=merge-back-symref-before-swap:mb-other bash "$SDD_STATE" merge-back docs/plan2.md 11 --session s3 --commit "$y11" 2>/dev/null); rc=$?
if [ -f "$TEST_ROOT/mb.sym.seam" ] && [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=11 head=${y11:0:7}" ] && [ "$(git -C "$mb_a" rev-parse mb-other)" = "$h11" ] && ! git -C "$mb_a" symbolic-ref -q refs/heads/feat >/dev/null 2>&1 && [ "$(git -C "$mb_a" rev-parse feat)" = "$y11" ]; then pass "an integration ref made symbolic after merge-back's check is overwritten as itself, the branch it pointed to unmoved"; else fail "an integration ref made symbolic after merge-back's check is overwritten as itself, the branch it pointed to unmoved (rc=$rc: $out mb-other=$(git -C "$mb_a" rev-parse mb-other))"; fi
git -C "$mb_a" update-ref -d refs/heads/mb-other
```

Write `<sw>/snippets/t4-e7d-aw.sh`:

```bash
# amend and a symbolic plan ref: refused at the check, and a ref made symbolic after the check is overwritten as itself by the swap.
hs_aw=$(git -C "$aw" rev-parse feat); git -C "$aw" update-ref refs/heads/aw-other "$hs_aw"; git -C "$aw" symbolic-ref refs/heads/feat refs/heads/aw-other
lg_awsym=$(cksum < "$wsaw/progress.md"); am_awsym=$(ls -A "$wsaw/amends" 2>/dev/null)
aw_amend sym
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && grep -qF "the plan ref feat is a symbolic ref; amend writes only a branch that holds a commit" "$TEST_ROOT/aw.err" && [ "$(git -C "$aw" rev-parse aw-other)" = "$hs_aw" ] && [ "$(cksum < "$wsaw/progress.md")" = "$lg_awsym" ] && [ "$(ls -A "$wsaw/amends" 2>/dev/null)" = "$am_awsym" ]; then pass "amend refuses a symbolic plan ref and leaves the branch it points to unmoved"; else fail "amend refuses a symbolic plan ref and leaves the branch it points to unmoved (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/aw.err"))"; fi
git -C "$aw" update-ref --no-deref refs/heads/feat "$hs_aw"; git -C "$aw" update-ref refs/heads/aw-other "$hs_aw"
aw_amend sym2 HYPERPOWERS_TEST_WRITER_AT=amend-symref-before-swap:aw-other
if [ -f "$seam_aw" ] && [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$(git -C "$aw" rev-parse aw-other)" = "$hs_aw" ] && ! git -C "$aw" symbolic-ref -q refs/heads/feat >/dev/null 2>&1 && [ "$(git -C "$aw" rev-parse "feat^")" = "$hs_aw" ]; then pass "a plan ref made symbolic after amend's check is overwritten as itself, the branch it pointed to unmoved"; else fail "a plan ref made symbolic after amend's check is overwritten as itself, the branch it pointed to unmoved (rc=$rc: $out aw-other=$(git -C "$aw" rev-parse aw-other))"; fi
git -C "$aw" update-ref -d refs/heads/aw-other
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'a divergent merge keeps both parents and the integration-only content' <sw>/snippets/t4-e7d-mb.sh
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before '# The link variant:' <sw>/snippets/t4-e7d-aw.sh
```

Expected: both exit 0.

Then update the `racegit` wrapper, whose positional match would miss the new `--no-deref` swap. With the Edit tool, in `tests/sdd/test-sdd-state.sh`, replace

```text
if [ "$3" = update-ref ] && [ "$4" = -m ]; then case "$5" in "sdd merge-back task "*) tip=$("$real" -C "$2" rev-parse "$6") && adv=$("$real" -C "$2" commit-tree "$tip^{tree}" -p "$tip" -m race) && "$real" -C "$2" update-ref "$6" "$adv" "$tip" && echo "$adv" >> "%s" ;; esac; fi
```

with

```text
if [ "$3" = update-ref ] && [ "$4" = --no-deref ] && [ "$5" = -m ]; then case "$6" in "sdd merge-back task "*) tip=$("$real" -C "$2" rev-parse "$7") && adv=$("$real" -C "$2" commit-tree "$tip^{tree}" -p "$tip" -m race) && "$real" -C "$2" update-ref "$7" "$adv" "$tip" && echo "$adv" >> "%s" ;; esac; fi
```

- [ ] **Step 9: Run E7-d red**

Write `<sw>/snippets/t4-e7d-mbseam.txt`:

```bash
    # Test seam: HYPERPOWERS_TEST_WRITER_AT=merge-back-symref-before-swap:<branch>
    # makes the integration ref a symbolic ref to refs/heads/<branch> after
    # the check and before the swap, once.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in merge-back-symref-before-swap:*) [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; git -C "$code" symbolic-ref "$ref" "refs/heads/${HYPERPOWERS_TEST_WRITER_AT#merge-back-symref-before-swap:}"; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

Write `<sw>/snippets/t4-e7d-amseam.txt`:

```bash
    # Test seam: HYPERPOWERS_TEST_WRITER_AT=amend-symref-before-swap:<branch>
    # makes the plan ref a symbolic ref to refs/heads/<branch> after the check
    # and before the swap, once.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in amend-symref-before-swap:*) [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; git -C "$REPO" symbolic-ref "refs/heads/$ref" "refs/heads/${HYPERPOWERS_TEST_WRITER_AT#amend-symref-before-swap:}"; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

```bash
bash <sw>/make-red.sh <worktree> t4-e7d
python3 <sw>/insert-at.py <sw>/red/t4-e7d/skills/subagent-driven-development/scripts/sdd-state after 'merge-back-before-swap:*)' <sw>/snippets/t4-e7d-mbseam.txt
python3 <sw>/insert-at.py <sw>/red/t4-e7d/skills/subagent-driven-development/scripts/sdd-state after 'in amend-before-swap:*) git -C "$REPO" update-ref' <sw>/snippets/t4-e7d-amseam.txt
bash <sw>/run-slices.sh <sw>/red/t4-e7d mergeback amendwt > <sw>/logs/t4-e7d.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t4-e7d.red.log > <sw>/logs/t4-e7d.red.fails
```

Expected: exit 1; the fails list holds the four E7-d labels (at e62fdb5 both commands write through the symbolic ref and move the branch it names), "three lost swaps give up naming both heads and publish nothing" (the updated wrapper matches only the `--no-deref` swap, which e62fdb5 does not make), the Task 10 graft label, the two E8-e labels, and the Task 2 labels in the `aw` block whose fixes and seams the red tree lacks. Merge-back labels after "three lost swaps" may fail downstream of it.

- [ ] **Step 10: Implement E7-d**

The spec puts the refusal before any write, so each command checks once right before its first write and again on every attempt. In `cmd_amend`, with the Edit tool, replace

```text
  hp_contained "$ROOT" "plans/$WS/amends" || { hp_unlock; echo "status=error"; return 2; }
```

with

```text
  # A symbolic plan ref is refused before amend's first write: the
  # crash-window refresh, the bookkeeping and the record below all assume
  # the ref is the branch the plan line registered. The attempt loop checks
  # again, as another writer can make it one meanwhile.
  if git -C "$REPO" symbolic-ref -q "refs/heads/$ref" >/dev/null 2>&1; then hp_unlock; echo "sdd-state: the plan ref $ref is a symbolic ref; amend writes only a branch that holds a commit" >&2; echo "status=error"; return 2; fi
  hp_contained "$ROOT" "plans/$WS/amends" || { hp_unlock; echo "status=error"; return 2; }
```

In `cmd_merge_back`, replace

```text
  record="$WSDIR/merges/task-$n"
```

with

```text
  # A symbolic integration ref is refused before merge-back's first write;
  # the attempt loop checks again, as another writer can make it one
  # meanwhile.
  if git -C "$code" symbolic-ref -q "$ref" >/dev/null 2>&1; then hp_unlock; echo "sdd-state: the integration branch $integ is a symbolic ref; merge-back writes only a branch that holds a commit" >&2; echo "status=error"; return 2; fi
  record="$WSDIR/merges/task-$n"
```

Then, in `cmd_amend`, replace

```text
  for _ in 1 2 3; do
    P=$(git -C "$REPO" rev-parse -q --verify "refs/heads/$ref^{commit}") || { hp_unlock; echo "status=error"; return 2; }
```

with

```text
  for _ in 1 2 3; do
    # The swap writes the plan ref itself, never through it (--no-deref), so
    # a symbolic ref is refused here: amend would otherwise move the branch
    # it names, which no plan line registered. Checked on every attempt, as
    # another writer can make it one between attempts.
    if git -C "$REPO" symbolic-ref -q "refs/heads/$ref" >/dev/null 2>&1; then rm -f "$record"; hp_unlock; echo "sdd-state: the plan ref $ref is a symbolic ref; amend writes only a branch that holds a commit" >&2; echo "status=error"; return 2; fi
    P=$(git -C "$REPO" rev-parse -q --verify "refs/heads/$ref^{commit}") || { hp_unlock; echo "status=error"; return 2; }
```

Replace the end of the `amend-wt-before-swap` seam (Task 2, Step 4)

```text
        git -C "$REPO" update-ref "refs/heads/$ref" "${sv%%:*}" 2>/dev/null
        HYPERPOWERS_TEST_WRITER_AT="" ;;
    esac
```

with the same three lines followed by the content of `<sw>/snippets/t4-e7d-amseam.txt`, unchanged, and replace

```text
    if uerr=$(git -C "$REPO" update-ref -m "sdd amend" "refs/heads/$ref" "$commit" "$P" 2>&1); then
```

with

```text
    if uerr=$(git -C "$REPO" update-ref --no-deref -m "sdd amend" "refs/heads/$ref" "$commit" "$P" 2>&1); then
```

In `cmd_merge_back`, replace

```text
  for _ in 1 2 3; do
    H=$(git -C "$code" rev-parse -q --verify "$ref^{commit}" 2>/dev/null) || { hp_unlock; echo "sdd-state: the integration branch $integ does not exist in $code" >&2; echo "status=error"; return 2; }
```

with

```text
  for _ in 1 2 3; do
    # The swap writes the integration ref itself, never through it
    # (--no-deref), so a symbolic ref is refused here: merge-back would
    # otherwise move the branch it names, which no plan line registered.
    # Checked on every attempt, as another writer can make it one between
    # attempts.
    if git -C "$code" symbolic-ref -q "$ref" >/dev/null 2>&1; then hp_unlock; echo "sdd-state: the integration branch $integ is a symbolic ref; merge-back writes only a branch that holds a commit" >&2; echo "status=error"; return 2; fi
    H=$(git -C "$code" rev-parse -q --verify "$ref^{commit}" 2>/dev/null) || { hp_unlock; echo "sdd-state: the integration branch $integ does not exist in $code" >&2; echo "status=error"; return 2; }
```

and replace

```text
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in merge-back-before-swap:*) git -C "$code" update-ref "$ref" "${HYPERPOWERS_TEST_WRITER_AT#merge-back-before-swap:}" 2>/dev/null; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
    if uerr=$(git -C "$code" update-ref -m "sdd merge-back task $n" "$ref" "$new" "$H" 2>&1); then
```

with

```text
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in merge-back-before-swap:*) git -C "$code" update-ref "$ref" "${HYPERPOWERS_TEST_WRITER_AT#merge-back-before-swap:}" 2>/dev/null; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
<content of <sw>/snippets/t4-e7d-mbseam.txt>
    if uerr=$(git -C "$code" update-ref --no-deref -m "sdd merge-back task $n" "$ref" "$new" "$H" 2>&1); then
```

The `<content of ...>` line stands for the snippet's four lines, unchanged.

- [ ] **Step 11: Run E7-d green**

```bash
bash <sw>/run-slices.sh <worktree> amend mergeback > <sw>/logs/t4-e7d.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 12: Docs and CHANGELOG for E7-d**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`merge-back\` and \`amend\` refuse a symbolic integration or plan ref, and their swaps no longer follow one made symbolic after that check."
```

Expected: the two SDD pages refreshed, digests only.

- [ ] **Step 13: Commit E7-d**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t4-e7d.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t4-e7d.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t4-e7d.staged.diff
git -C <worktree> commit -m "fix(sdd-state): merge-back and amend refuse a symbolic ref and never write through one"
```

Expected: lint exit 0; `hits: 0`.

**Finding E7-b, the seven-character approval line.**

- [ ] **Step 14: Rewrite the approval-token tests**

The four Task 7 tests at `test-sdd-state.sh:4606-4628` (a token naming no commit, a tag object, a seven-character collision, a hex-named ref) test the `--disambiguate` resolution this finding removes; the new tests replace them. Write `<sw>/snippets/t4-e7b-tok.sh`:

```bash
# The approval line names the approved commit by its full id, as wide as this repository's ids, and merge-back compares the ids whole: a seven-character token, a longer hex run, a fragment and an unterminated last line all read as no approval, and another commit's full id is not-approved naming it.
z7=${z1:0:7}
printf 'Task 7: approved %s\n' "$z7" >> "$wsmb2/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan2.md 7 --session s3 --commit "$z1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$h7" ]; then pass "a seven-character approval line reads as no approval"; else fail "a seven-character approval line reads as no approval (rc=$rc: $out)"; fi
printf 'Task 7: approved %s0\n' "$z1" >> "$wsmb2/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan2.md 7 --session s3 --commit "$z1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$h7" ]; then pass "a 41-digit token reads as no approval"; else fail "a 41-digit token reads as no approval (rc=$rc: $out)"; fi
printf 'Task 7: approved %s\t#fragment\n' "$z1" >> "$wsmb2/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan2.md 7 --session s3 --commit "$z1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$h7" ]; then pass "a full-id approval line ending in a #fragment marker reads as no approval"; else fail "a full-id approval line ending in a #fragment marker reads as no approval (rc=$rc: $out)"; fi
printf 'Task 7: approved %s' "$z1" >> "$wsmb2/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan2.md 7 --session s3 --commit "$z1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$h7" ]; then pass "a full-id approval line left unterminated at the ledger's end reads as no approval"; else fail "a full-id approval line left unterminated at the ledger's end reads as no approval (rc=$rc: $out)"; fi
printf '\t#fragment\n' >> "$wsmb2/progress.md"
printf 'Task 7: approved %s\n' "$h7" >> "$wsmb2/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan2.md 7 --session s3 --commit "$z1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=${h7:0:7}" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$h7" ]; then pass "another commit's full id gives not-approved naming its seven characters"; else fail "another commit's full id gives not-approved naming its seven characters (rc=$rc: $out)"; fi
```

```bash
python3 <sw>/replace-range.py <worktree>/tests/sdd/test-sdd-state.sh '# The approval token is resolved to exactly one commit in the code repository' 'update-ref -d "refs/heads/$zp"' <sw>/snippets/t4-e7b-tok.sh
perl -pi -e 's/"\$\{([a-z0-9]+):0:7\}"/"\$$1"/g if /approved %s/' <worktree>/tests/sdd/test-sdd-state.sh
grep -n 'approved %s' <worktree>/tests/sdd/test-sdd-state.sh > <sw>/logs/t4-e7b.approved-lines.txt
```

Expected: replace-range exits 0. Read `t4-e7b.approved-lines.txt`: every `printf '... approved %s...'` line passes a full id (`"$t1"`, `"$x1" "$y1"`, `"$z1"`, `"$g1"`, `"$y11"` and the rest), except the deliberate `"$z7"`, `%s0`, fragment, unterminated and `"$h7"` lines of the new block. No `:0:7}` remains on an approval line.

Write `<sw>/snippets/t4-e7b-s2r.sh`:

```bash
# In a SHA-256 repository the approval names the 64-digit id: a 40-digit prefix of it is no approval, and the full id merges.
s2r="$TEST_ROOT/s2r"; git init -q -b main --object-format=sha256 "$s2r"; git -C "$s2r" config user.name "Test Bot"; git -C "$s2r" config user.email "test@example.com"
mkdir -p "$s2r/docs" "$s2r/src"; : > "$s2r/docs/spec.md"; printf '# S\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$s2r/docs/plan.md"; printf 'base\n' > "$s2r/src/a.txt"; git -C "$s2r" add docs src; git -C "$s2r" commit -qm base; git -C "$s2r" switch -q -c feat
ws2r=$(run_sdd_dir "$s2r" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$ws2r/progress.md"
run_state "$s2r" register docs/plan.md --session s1 --integration feat >/dev/null; git -C "$s2r" switch -q --detach
run_state "$s2r" claim docs/plan.md 1 --session s1 >/dev/null
git -C "$s2r" switch -q "feat.$(basename "$ws2r" | sed 's/.*-//').task-1"; printf 'one\n' > "$s2r/src/a.txt"; git -C "$s2r" commit -qam one; s2c=$(git -C "$s2r" rev-parse HEAD); git -C "$s2r" switch -q --detach feat
printf 'Task 1: approved %s\n' "${s2c:0:40}" >> "$ws2r/progress.md"
out=$(run_state "$s2r" merge-back docs/plan.md 1 --session s1 --commit "$s2c" 2>/dev/null); rc=$?
if [ "${#s2c}" -eq 64 ] && [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ] && [ "$(git -C "$s2r" rev-parse feat)" != "$s2c" ]; then pass "in a SHA-256 repository a 40-digit prefix of the commit's id reads as no approval"; else fail "in a SHA-256 repository a 40-digit prefix of the commit's id reads as no approval (len=${#s2c} rc=$rc: $out)"; fi
printf 'Task 1: approved %s\n' "$s2c" >> "$ws2r/progress.md"
out=$(run_state "$s2r" merge-back docs/plan.md 1 --session s1 --commit "$s2c" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=1 head=${s2c:0:7}" ] && [ "$(git -C "$s2r" rev-parse feat)" = "$s2c" ]; then pass "in a SHA-256 repository the 64-digit id merges"; else fail "in a SHA-256 repository the 64-digit id merges (rc=$rc: $out)"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'git -C "$mb_a" update-ref -d refs/heads/mb-other' <sw>/snippets/t4-e7b-s2r.sh`
Expected: exit 0.

Write `<sw>/snippets/t4-e7b-contract.sh`:

```bash
assert_contains "$SDD" "Task <N>: approved <full id>" "the approved line carries the full commit id"
assert_contains "$SDD" "written with \`git rev-parse <head>\`" "the approved id is written with git rev-parse"
assert_contains "$SDD" "merge-back compares the whole id, so a shortened id reads as no approval" "a shortened approval id reads as no approval"
assert_not_contains "$SDD" "cut -c1-7" "no seven-character approval instruction remains"
assert_not_contains "$SDD" "Task <N>: approved <sha7>" "no seven-character approval line remains"
assert_contains "$SDD_EXAMPLE_WORKFLOW" "[Ledger: Task 1: approved d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3]" "the example workflow's approval line carries a full id"
```

Run: `python3 <sw>/replace-range.py <worktree>/tests/sdd/test-sdd-contract.sh 'assert_contains "$SDD" "Task <N>: approved <sha7>"' 'the approved sha is exactly seven characters' <sw>/snippets/t4-e7b-contract.sh`
Expected: `replaced lines 471-472 of ...`.

- [ ] **Step 15: Run E7-b red**

```bash
bash <sw>/make-red.sh <worktree> t4-e7b
bash <sw>/run-slices.sh <sw>/red/t4-e7b mergeback > <sw>/logs/t4-e7b.red.log 2>&1
bash <sw>/red/t4-e7b/tests/sdd/test-sdd-contract.sh > <sw>/logs/t4-e7b.red.contract.log 2>&1
grep -F '[FAIL]' <sw>/logs/t4-e7b.red.log > <sw>/logs/t4-e7b.red.fails
grep -F '[FAIL]' <sw>/logs/t4-e7b.red.contract.log > <sw>/logs/t4-e7b.red.contract.fails
```

Expected: both exit 1. `t4-e7b.red.fails` includes "a seven-character approval line reads as no approval" (at e62fdb5 the seven characters resolve to `z1` and it merges), "in a SHA-256 repository the 64-digit id merges" (at e62fdb5 only a seven-character token is read), and the merges that now pass a full id (at e62fdb5 a full id is no seven-character token, so they answer `not-approved approved=none`); later Task 7 labels fail downstream of the first merge, and the E8-e, Task 10 and E7-d labels fail for want of their fixes and seams. "a 41-digit token reads as no approval", the fragment, unterminated and 40-digit-prefix labels pass at e62fdb5 too, which reads none of them as an approval; they pin the new reader. `t4-e7b.red.contract.fails` holds the three new positive SDD needles and the example-workflow needle; the two `assert_not_contains` needles fail as well, because e62fdb5's SKILL.md still carries both strings.

- [ ] **Step 16: Implement E7-b in merge-back**

In `cmd_merge_back`, with the Edit tool, replace the locals

```text
  local plan="" n="" sid="" sha="" code="" rc out line integ ref owner_f owner full approved approved_full
  local pair blob tmp graph title deps d waiting c lease lowner wt record H new mt mrc tree paths published t uerr cur o nc
```

with

```text
  local plan="" n="" sid="" sha="" code="" rc out line integ ref owner_f owner full approved recs
  local pair blob tmp graph title deps d waiting c lease lowner wt record H new mt mrc tree paths published t uerr cur
```

and replace the block from

```text
  # The newest approval line names the approved commit; a longer hex run is
  # some other token, not a seven-character abbreviation.
```

through

```text
  [ "$sha" = "$approved_full" ] || { hp_unlock; echo "status=not-approved approved=$approved"; return 12; }
```

(the grep, the resolution comment, the `--disambiguate` loop and the comparison) with

```text
  # The newest approval record names the approved commit by its full id, as
  # wide as this repository's ids (40 or 64 hex digits); a shorter or longer
  # hex run is some other token and reads as no approval. Records come
  # through ledger_records, so an interrupted approval write (an
  # unterminated last line, or a line ending in a fragment marker) never
  # authorizes a merge. The ids are compared whole: no prefix, abbreviation
  # or revision lookup stands between the line and the commit.
  recs=$(ledger_records "$WSDIR/progress.md") || { hp_unlock; echo "status=error"; return 2; }
  approved=$(printf '%s\n' "$recs" | grep -E "^Task $n: approved [0-9a-f]{${#sha}}([^0-9a-f]|\$)" | tail -n 1 | cut -d' ' -f4 | cut -c1-"${#sha}")
  [ -n "$approved" ] || { hp_unlock; echo "status=not-approved approved=none"; return 12; }
  [ "$approved" = "$sha" ] || { hp_unlock; echo "status=not-approved approved=${approved:0:7}"; return 12; }
```

Run: `grep -nE 'approved_full|disambiguate|\bnc\b' <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t4-e7b.leftovers.txt` and read it: no line inside `cmd_merge_back` remains.

- [ ] **Step 17: Implement E7-b in the skill text**

In `skills/subagent-driven-development/SKILL.md`, with the Edit tool, replace

```text
- Append `Task <N>: approved <sha7>` with the head the reviewers saw (every
  later approval of the same task appends a new line; the newest is what
  merges). `<sha7>` is exactly the first seven characters of the full id:
  write it with `git rev-parse <head> | cut -c1-7`, never
  `git rev-parse --short`, which prints more than seven characters in a large
  repository, and merge-back accepts exactly seven, so a longer token reads
  as no approval.
```

with

```text
- Append `Task <N>: approved <full id>` with the head the reviewers saw,
  written with `git rev-parse <head>` (every later approval of the same task
  appends a new line; the newest is what merges). merge-back compares the
  whole id, so a shortened id reads as no approval.
```

The `not-approved approved=<sha7|none>` sentence below it (`SKILL.md:806`) keeps its form: the status names seven characters.

In `skills/subagent-driven-development/example-workflow.md`, replace `[Ledger: Task 1: approved d4e5f6a]` with `[Ledger: Task 1: approved d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3]` and `[Ledger: Task 2: approved b7c8d9e]` with `[Ledger: Task 2: approved b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6]`.

In `docs/site/advanced/sdd-internals.md`, replace `an \`approved <sha7>\` line for the head the reviewers saw` with `an \`approved <full id>\` line for the head the reviewers saw` (`:43`), and `the controller appends \`Task N: approved <sha7>\`` with `the controller appends \`Task N: approved <full id>\`` (`:61`).

- [ ] **Step 18: Run E7-b green**

```bash
bash <sw>/run-slices.sh <worktree> mergeback > <sw>/logs/t4-e7b.green.log 2>&1
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t4-e7b.green.contract.log 2>&1
```

Expected: both exit 0; `STATUS: PASSED` in the slice log, no `[FAIL]` in the contract log.

- [ ] **Step 19: Docs and CHANGELOG for E7-b**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "The approval line now carries the full commit id (\`Task N: approved <full id>\`), which merge-back compares whole and reads only from complete ledger records; a seven-character line reads as no approval, so a ledger in flight at upgrade re-appends one approval line per open task."
```

Expected: the helper prints the fifteen pages whose sources include the SDD SKILL.md or its directory: the two SDD pages and the thirteen listed under **Files** as digest-only. Re-read each printed page for the approval line: at plan time only sdd-internals (`:43`, `:61`, edited in Step 17) names it; `grep -rn 'sha7' <worktree>/docs/site/*.md <worktree>/docs/site/*/*.md > <sw>/logs/t4-e7b.sha7.txt` must list no approval-line mention (a `not-approved approved=<sha7|none>` mention is correct and stays).

- [ ] **Step 20: Commit E7-b**

```bash
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t4-e7b.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/example-workflow.md tests/sdd/test-sdd-state.sh tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md docs/site/recommended-settings.md docs/site/advanced/codex-gates.md docs/site/advanced/triggering.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/using-hyperpowers.md docs/site/skills/executing-plans.md docs/site/skills/writing-plans.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/test-driven-development.md docs/site/skills/requesting-code-review.md docs/site/skills/receiving-code-review.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t4-e7b.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t4-e7b.staged.diff
git -C <worktree> commit -m "fix(sdd): the approval line carries the full commit id, compared whole by merge-back"
```

Expected: lint exit 0; `hits: 0`. A page the helper did not print is dropped from the `git add` list rather than staged unchanged (staging an unchanged path is harmless, but the list should match the helper's output).

- [ ] **Step 21: Verify Task 4**

```bash
bash <sw>/run-slices.sh <worktree> amend mergeback > <sw>/logs/t4.slices.log 2>&1
bash <worktree>/tests/claude-code/test-sdd-dir-path.sh > <sw>/logs/t4.pkg.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t4` (changed scripts: `sdd-state`, `review-package`, `tests/claude-code/test-sdd-dir-path.sh`, `tests/sdd/test-sdd-contract.sh`). Report the three red runs with their FAIL labels, and the exempt tests: the 41-digit, fragment, unterminated and 40-digit-prefix approval tests (they pass at e62fdb5, which reads no full id as an approval; they pin the new reader). The full-id merges are not exempt: they are defect-caused red evidence (at e62fdb5 a full id is no seven-character token and answers `not-approved`).

Correction (2026-11-10), decision 1 (The approval line carries the full commit id): merge-back takes the newest complete `Task <N>: approved` record first and then checks its token. A token that is not exactly the repository's id width (40 or 64 hex digits, followed by a non-hex character or the line's end) reads as no approval, `approved=none`, even when an older record holds a valid full id. Spec E7-b's "takes the newest record matching `^Task <N>: approved [0-9a-f]{W}([^0-9a-f]|$)`" skipped such a line and let the older record authorize, against this decision's "a shortened id reads as no approval" and the skill text's "the newest merges". The Task 4 Codex task gate found it in round 1; the user chose this reading.

Correction (2026-11-10), decision 1 (The approval line carries the full commit id): the approval id must be followed by whitespace or the line's end, `^Task <N>: approved [0-9a-f]{W}([[:space:]]|$)`, where spec E7-b allowed any non-hex character after it. An approval cut off after its id, with the next append landing on the same line (`Task 7: approved <id>Task 8: ...`), is then no approval; a trailing note after a space still reads. The Task 4 Codex task gate found it in round 3; the change was applied beyond the task's five-round cap at the user's direction, checked by a scoped re-review and the covering slices only.

### Task 5: Single findings

**Risk tier:** high — `claim`'s lock order and `register`'s recorded root are concurrency and identity code, and the parser change decides which tasks exist.

**Depends on:** Task 4

**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh`
- Test: `tests/sdd/test-sdd-state.sh`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`
- Modify (digest only, through `sdd-common.sh`): `docs/site/skills/using-hyperpowers.md`

**Interfaces:**
- Consumes: `code_repo_arg` (`sdd-state:129`), `hp_lock_pair`/`hp_lock`, `hp_plan_graph`'s awk (`sdd-common.sh:271-280`), `enc`'s callers (every path-valued status field).
- Produces: `root_of <repo> [<rev>]` (HEAD unless a revision is given); `register` records `code-root` from `refs/heads/<integration>` when that branch exists; `claim_take_locks` resolves the code repository before either lock; `deps --from` hashes and parses one private copy; a `### Task` heading followed by a word, a colon or nothing is `malformed task heading: <line>`; `enc` escapes control characters as `%XX`. Seams: `HYPERPOWERS_TEST_WRITER_AT=deps-from-after-copy:<file>` and the crash seam `HYPERPOWERS_TEST_CRASH_AT=claim-takeover-after-rename`, each touching the seam marker.

**Mirror:** `sdd-state:246-250` (`authoritative_plan_blob`'s private copy) for E1; `tests/sdd/test-sdd-state.sh:3125-3129` (`dep_bad`) for E4; `tests/sdd/test-sdd-state.sh:3648-3654` (the owner-retry crash test) for E3-f; `sdd-state:880` (the fresh claim's crash seam) for the new seam.

**Finding E1, `deps --from` reads its file twice.**

- [ ] **Step 1: Write the E1 test**

Write `<sw>/snippets/t5-e1-test.sh`:

```bash
# deps --from reads its file once, into a private copy it hashes and parses: a writer that replaces the file after the copy changes neither plan= nor the graph.
printf '# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** Task 1\n' > "$dp/docs/dep.from1.md"
printf '# P\n\n### Task 1: A\n\n**Depends on:** none\n\n### Task 2: B\n\n**Depends on:** none\n\n### Task 3: C\n\n**Depends on:** none\n' > "$TEST_ROOT/dep.from2"
b_from1=$(git -C "$dp" hash-object docs/dep.from1.md); rm -f "$TEST_ROOT/dep.seam"
out=$(cd "$dp" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/dep.seam" HYPERPOWERS_TEST_WRITER_AT="deps-from-after-copy:$TEST_ROOT/dep.from2" bash "$SDD_STATE" deps --from docs/dep.from1.md docs/plan.md 2>/dev/null); rc=$?
if [ -f "$TEST_ROOT/dep.seam" ] && [ "$rc" -eq 0 ] && [ "$out" = "$(printf 'status=deps plan=%s tasks=2\ntask=1 depends=none\ntask=2 depends=1' "${b_from1:0:7}")" ] && cmp -s "$dp/docs/dep.from1.md" "$TEST_ROOT/dep.from2"; then pass "deps --from hashes and parses one copy of its file, whatever happens to the file after the copy"; else fail "deps --from hashes and parses one copy of its file, whatever happens to the file after the copy (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'dep_bad twice' <sw>/snippets/t5-e1-test.sh`
Expected: exit 0.

- [ ] **Step 2: Run E1 red**

Write `<sw>/snippets/t5-e1-seam.txt`:

```bash
    # Test seam: HYPERPOWERS_TEST_WRITER_AT=deps-from-after-copy:<file>
    # replaces the --from file with <file> right after it was read, once.
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in deps-from-after-copy:*) [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; cp "${HYPERPOWERS_TEST_WRITER_AT#deps-from-after-copy:}" "$from"; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
```

```bash
bash <sw>/make-red.sh <worktree> t5-e1
python3 <sw>/insert-at.py <sw>/red/t5-e1/skills/subagent-driven-development/scripts/sdd-state after 'tmp=$from; blob=$(git -C "$REPO" hash-object "$from")' <sw>/snippets/t5-e1-seam.txt
bash <sw>/run-slices.sh <sw>/red/t5-e1 deps > <sw>/logs/t5-e1.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t5-e1.red.log > <sw>/logs/t5-e1.red.fails
```

Expected: exit 1; the fails list holds exactly the E1 label (at e62fdb5 `plan=` is the first file's id and the graph is the replacement's three tasks).

- [ ] **Step 3: Implement E1**

In `cmd_deps`, with the Edit tool, replace

```text
    # One absolute path for the hash and the parse: git -C "$REPO" would
    # otherwise resolve a relative --from against the plan repository while the
    # parser reads it from the caller's directory.
    from=$(cd "$(dirname "$from")" 2>/dev/null && pwd -P)/$(basename "$from")
    tmp=$from; blob=$(git -C "$REPO" hash-object "$from") || { echo "status=error"; return 2; }
```

with

```text
    # One absolute path for the attributes the hash applies: git -C "$REPO"
    # would otherwise resolve a relative --from against the plan repository.
    from=$(cd "$(dirname "$from")" 2>/dev/null && pwd -P)/$(basename "$from")
    # The file is read once, into a private copy that is hashed and parsed,
    # so a concurrent edit cannot pair one plan= with another text's graph or
    # a false clean. --path keeps the attributes the file's own path selects,
    # so plan= stays the id amend computes for the same file.
    tmp=$(mktemp "${TMPDIR:-/tmp}/sdd-plan.XXXXXX") || { echo "status=error"; return 2; }
    cp "$from" "$tmp" || { rm -f "$tmp"; echo "status=error"; return 2; }
<content of <sw>/snippets/t5-e1-seam.txt>
    blob=$(git -C "$REPO" hash-object --path="$from" -- "$tmp") || { rm -f "$tmp"; echo "status=error"; return 2; }
```

The `<content of ...>` line stands for the snippet's three lines, unchanged. Then, with `replace_all`, replace `[ -n "$from" ] || rm -f "$tmp"` (three occurrences, all in `cmd_deps`) with `rm -f "$tmp"`: both branches now own their copy. In `cmd_amend`, replace `# One absolute path for the hash and the parse, as deps takes it: git -C` with `# One absolute path for the hash and the parse: git -C`.

- [ ] **Step 4: Run E1 green**

```bash
bash <sw>/run-slices.sh <worktree> deps amend > <sw>/logs/t5-e1.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 5: Docs, CHANGELOG and commit for E1**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`deps --from\` reads its file once, into a private copy it hashes and parses, so a concurrent edit cannot pair one \`plan=\` with another text's graph."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t5-e1.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t5-e1.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e1.staged.diff
git -C <worktree> commit -m "fix(sdd-state): deps --from hashes and parses one private copy of its file"
```

Expected: the two SDD pages refreshed, digests only; lint exit 0; `hits: 0`.

**Finding E2, `register` records the checkout's root.**

- [ ] **Step 6: Write the E2 test**

Write `<sw>/snippets/t5-e2-test.sh`:

```bash
# register records the code root of the integration branch, not of the code checkout's HEAD: a checkout on an unrelated orphan branch at registration would otherwise leave a code root that verify and next refuse once the integration branch is checked out.
e2p="$TEST_ROOT/e2p"; make_repo "$e2p"; git -C "$e2p" switch -q -c plans
mkdir -p "$e2p/docs"; : > "$e2p/docs/spec.md"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Depends on:** none\n' > "$e2p/docs/plan.md"; git -C "$e2p" add docs; git -C "$e2p" commit -qm plan
e2c="$TEST_ROOT/e2c"; make_repo "$e2c"; git -C "$e2c" commit -q --amend --allow-empty -m "code root"; ra_e2=$(git -C "$e2c" rev-parse main)
git -C "$e2c" switch -q --orphan side; git -C "$e2c" commit -q --allow-empty -m "side root"
wse2=$(run_sdd_dir "$e2p" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wse2/progress.md"
out=$(run_state "$e2p" register docs/plan.md --session s1 --integration main --code-repo "$e2c" 2>/dev/null); rc=$?
git -C "$e2c" switch -q main
out1=$(run_state "$e2p" verify docs/plan.md --code-repo "$e2c" 2>/dev/null); rc1=$?
out2=$(run_state "$e2p" next docs/plan.md --session s1 --code-repo "$e2c" 2>/dev/null); rc2=$?
if [ "$rc" -eq 0 ] && grep -q "^plan: integration main code-root ${ra_e2:0:7} " "$wse2/progress.md" && [ "$rc1" -eq 0 ] && [ "$out1" = "status=ok tasks=0" ] && [ "$rc2" -eq 0 ] && [ "${out2%% plan=*}" = "status=next tasks=1 own-blocked=none" ]; then pass "register records the integration branch's code root, not the checkout's HEAD, and verify and next accept the integration checkout"; else fail "register records the integration branch's code root, not the checkout's HEAD, and verify and next accept the integration checkout (register rc=$rc: $out; verify rc=$rc1: $out1; next rc=$rc2: $out2; $(grep '^plan: ' "$wse2/progress.md"))"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'pass "hp_lock_pair takes the lower key first whichever role each repository plays"' <sw>/snippets/t5-e2-test.sh`
Expected: exit 0.

- [ ] **Step 7: Run E2 red**

```bash
bash <sw>/make-red.sh <worktree> t5-e2
bash <sw>/run-slices.sh <sw>/red/t5-e2 register > <sw>/logs/t5-e2.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t5-e2.red.log > <sw>/logs/t5-e2.red.fails
```

Expected: exit 1; the fails list holds exactly the E2 label. Probed at e62fdb5: the plan line records the side root, `verify` answers `ok` (it does not compare the code root), and `next` answers `status=wrong-repo` with exit 9; the `next` assertion is the one that proves the defect's effect.

- [ ] **Step 8: Implement E2**

In `sdd-state`, with the Edit tool, replace

```text
# The repository identity recorded at hand-off: the lexicographically
# smallest root commit of HEAD, stable across clones and hosts.
root_of() { git -C "$1" rev-list --max-parents=0 HEAD 2>/dev/null | sort | head -n 1; }
```

with

```text
# The repository identity recorded at hand-off: the lexicographically
# smallest root commit of a revision, HEAD unless one is given, stable
# across clones and hosts.
root_of() { git -C "$1" rev-list --max-parents=0 "${2:-HEAD}" 2>/dev/null | sort | head -n 1; }
```

and in `cmd_register` replace

```text
  plan_root=$(root_of "$REPO"); code_root=$(root_of "$code")
```

with

```text
  plan_root=$(root_of "$REPO")
  # The code root names the repository that owns the integration branch, so
  # it is read from that branch when it exists: the code checkout may stand
  # on an unrelated history (an orphan branch), whose root verify and next
  # would refuse once the integration branch is checked out. A branch not
  # created yet falls back to the checkout's HEAD.
  if git -C "$code" rev-parse -q --verify "refs/heads/$integration^{commit}" >/dev/null 2>&1; then
    code_root=$(root_of "$code" "refs/heads/$integration")
  else
    code_root=$(root_of "$code")
  fi
```

The plan root is left as it is: the spec's finding is the code root, and `plan_root` is read from the plan repository's own HEAD, the checkout the plan file was resolved in.

- [ ] **Step 9: Run E2 green**

```bash
bash <sw>/run-slices.sh <worktree> register claim2 next > <sw>/logs/t5-e2.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 10: Docs, CHANGELOG and commit for E2**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`register\` records the code root of the integration branch when that branch exists, not of the code checkout's HEAD."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t5-e2.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t5-e2.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e2.staged.diff
git -C <worktree> commit -m "fix(sdd-state): register records the integration branch's code root"
```

Expected: the two SDD pages refreshed. Re-read sdd-internals' `register` sentence: at plan time it does not say which commit the code root is read from, so digests only. Lint exit 0; `hits: 0`.

**Finding E3-c, a claim without a plan line skips the repository check.**

- [ ] **Step 11: Write the E3-c test**

Write `<sw>/snippets/t5-e3c-test.sh`:

```bash
# From outside any repository, a claim of a plan without a plan line checks the current directory's repository as next does, and answers what next answers there, publishing nothing.
make_repo "$TEST_ROOT/cl0n"; mkdir -p "$TEST_ROOT/cl0n/docs"; printf '# P\n\n### Task 1: A\n\n**Risk tier:** standard\n' > "$TEST_ROOT/cl0n/docs/plan.md"; git -C "$TEST_ROOT/cl0n" add docs; git -C "$TEST_ROOT/cl0n" commit -qm plan
ws0n=$(ws_path "$TEST_ROOT/cl0n" "$TEST_ROOT/cl0n/docs/plan.md"); mkdir -p "$ws0n"; printf '# SDD ledger — plan: docs/plan.md\n' > "$ws0n/progress.md"
mkdir -p "$TEST_ROOT/norepo"
outn=$(cd "$TEST_ROOT/norepo" && GIT_CEILING_DIRECTORIES="$TEST_ROOT" bash "$SDD_STATE" next "$TEST_ROOT/cl0n/docs/plan.md" --session s9 2>/dev/null); rcn=$?
out=$(cd "$TEST_ROOT/norepo" && GIT_CEILING_DIRECTORIES="$TEST_ROOT" bash "$SDD_STATE" claim "$TEST_ROOT/cl0n/docs/plan.md" 1 --session s9 2>/dev/null); rc=$?
if [ "$rc" -eq "$rcn" ] && [ "$out" = "$outn" ] && [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ ! -e "$ws0n/claims" ]; then pass "a claim without a plan line from outside any repository answers what next answers there"; else fail "a claim without a plan line from outside any repository answers what next answers there (claim rc=$rc: $out; next rc=$rcn: $outn)"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'pass "a claim without a plan line creates no branch"' <sw>/snippets/t5-e3c-test.sh`
Expected: exit 0.

- [ ] **Step 12: Run E3-c red**

```bash
bash <sw>/make-red.sh <worktree> t5-e3c
bash <sw>/run-slices.sh <sw>/red/t5-e3c claim2 > <sw>/logs/t5-e3c.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t5-e3c.red.log > <sw>/logs/t5-e3c.red.fails
```

Expected: exit 1; the fails list holds exactly the E3-c label (at e62fdb5 the claim skips `code_repo_arg` without a plan line and answers `status=claimed task=1 branch=none`, creating `claims/`).

- [ ] **Step 13: Implement E3-c**

In `cmd_claim`, with the Edit tool, replace

```text
  # A claim with a plan line writes a code ref, so it holds both repositories'
  # locks in the pair's order; without one it writes only state. A
  # --code-repo is validated whenever it is given, so a mistyped directory is
  # refused rather than silently ignored.
  claim_take_locks() {
    integ=""
    if [ -n "$line" ]; then
      integ=$(plan_field "$line" integration)
      code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
      hp_lock_pair "$PLAN_DIR" "$code" || return 2
    else
      if [ -n "$code" ]; then
        code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
      fi
      hp_lock "$PLAN_DIR" || return 2
    fi
  }
```

with

```text
  # A claim with a plan line writes a code ref, so it holds both repositories'
  # locks in the pair's order; without one it writes only state. The code
  # repository (--code-repo, or the current directory's) is checked first in
  # both cases, as next checks it, so a claim from outside any repository or
  # from a mistyped directory is refused rather than published.
  claim_take_locks() {
    integ=""
    code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
    if [ -n "$line" ]; then
      integ=$(plan_field "$line" integration)
      hp_lock_pair "$PLAN_DIR" "$code" || return 2
    else
      hp_lock "$PLAN_DIR" || return 2
    fi
  }
```

- [ ] **Step 14: Run E3-c green**

```bash
bash <sw>/run-slices.sh <worktree> claim claim2 next final-head finaltail > <sw>/logs/t5-e3c.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED`.

- [ ] **Step 15: Docs, CHANGELOG and commit for E3-c**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "\`claim\` checks the current directory's repository even for a plan without a plan line, as \`next\` does."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t5-e3c.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t5-e3c.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e3c.staged.diff
git -C <worktree> commit -m "fix(sdd-state): claim checks the current directory's repository without a plan line"
```

Expected: the two SDD pages refreshed, digests only; lint exit 0; `hits: 0`.

**Finding E3-f, a crash seam after the takeover's owner rename.** Test-only: the takeover's owner rename had no seam, so its owner-retry path was untested. Exempt from the red run (its subject is the new seam); no CHANGELOG sentence.

- [ ] **Step 16: Write the E3-f test and the seam**

Write `<sw>/snippets/t5-e3f-test.sh`:

```bash
# A takeover stopped after its owner rename (the crash seam) leaves its session's tasks waiting record, and the retry, which answers held own=1, removes it.
mkreg clt; clt=$MR_REPO; wsclt=$MR_WS
run_state "$clt" claim docs/plan.md 2 --session s-a >/dev/null 2>&1
run_state "$clt" wait docs/plan.md --session s-b --kind tasks --note "held: 2@s-a" >/dev/null 2>&1
rm -f "$TEST_ROOT/clt.seam"
( cd "$clt" && HYPERPOWERS_TEST_SEAM_MARK="$TEST_ROOT/clt.seam" HYPERPOWERS_TEST_CRASH_AT=claim-takeover-after-rename bash "$SDD_STATE" claim docs/plan.md 2 --session s-b --takeover >/dev/null 2>&1 ); rc=$?
if [ -f "$TEST_ROOT/clt.seam" ] && [ "$rc" -eq 99 ] && [ "$(sed -n 's/^session=//p' "$wsclt/claims/task-2/owner")" = s-b ] && [ "$(sed -n 's/^kind=//p' "$wsclt/waiting/s-b" 2>/dev/null)" = tasks ]; then pass "a takeover stopped after its owner rename leaves its session's waiting record"; else fail "a takeover stopped after its owner rename leaves its session's waiting record (rc=$rc)"; fi
out=$(run_state "$clt" claim docs/plan.md 2 --session s-b 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% branch=*}" = "status=held task=2 owner=s-b own=1" ] && [ ! -e "$wsclt/waiting/s-b" ]; then pass "the retry after a stopped takeover answers held own=1 and removes the record"; else fail "the retry after a stopped takeover answers held own=1 and removes the record (rc=$rc: $out)"; fi
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'retry removes its session' <sw>/snippets/t5-e3f-test.sh`
Expected: exit 0.

In `cmd_claim`'s takeover path, with the Edit tool, replace

```text
    if ! mv -f "$target/owner.new" "$target/owner"; then rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; fi
    if [ "$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)" != "$sid" ]; then hp_unlock; echo "status=error"; return 2; fi
```

with

```text
    if ! mv -f "$target/owner.new" "$target/owner"; then rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; fi
    if [ "$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)" != "$sid" ]; then hp_unlock; echo "status=error"; return 2; fi
    # Test seam: HYPERPOWERS_TEST_CRASH_AT=claim-takeover-after-rename stops a
    # takeover after its owner rename, before the branch, the activity stamp
    # and the waiting record's removal.
    if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = claim-takeover-after-rename ]; then [ -z "${HYPERPOWERS_TEST_SEAM_MARK:-}" ] || : > "$HYPERPOWERS_TEST_SEAM_MARK"; hp_unlock; exit 99; fi
```

- [ ] **Step 17: Run E3-f green and commit**

```bash
bash <sw>/run-slices.sh <worktree> claim2 > <sw>/logs/t5-e3f.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t5-e3f.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t5-e3f.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e3f.staged.diff
git -C <worktree> commit -m "test(sdd-state): a crash seam after the takeover's owner rename"
```

Expected: the slice exits 0 with `STATUS: PASSED`; the two SDD pages refreshed (the seam changes `sdd-state`), digests only; lint exit 0; `hits: 0`.

**Finding E4, task headings that drop their task.**

- [ ] **Step 18: Write the E4 tests**

Write `<sw>/snippets/t5-e4-test.sh`:

```bash
# A level-3 heading that names its task with a word, a colon alone or nothing is a malformed task heading, where it was read as prose and its task dropped; headings that only begin with the word Task still parse as no task.
# dep_head <name> <heading> <label>
dep_head() {
  printf '# P\n\n### Task 1: A\n\n%s\n\nbody\n' "$2" > "$dp/docs/dh.$1.md"
  out=$(run_state "$dp" deps --from "docs/dh.$1.md" docs/plan.md 2>"$TEST_ROOT/dh.$1.err"); rc=$?
  if [ "$rc" -eq 2 ] && [ "${out%% *}" = "status=invalid" ] && grep -qxF "malformed task heading: $2" "$TEST_ROOT/dh.$1.err"; then pass "$3"; else fail "$3 (rc=$rc: $out: $(tr '\n' '|' < "$TEST_ROOT/dh.$1.err"))"; fi
}
dep_head word '### Task One: x' "a heading ### Task One: x is a malformed task heading"
dep_head colon '### Task: x' "a heading ### Task: x is a malformed task heading"
dep_head bare '### Task' "a bare ### Task heading is a malformed task heading"
for dh in '### Tasks overview' '### Task-runner notes'; do
  printf '# P\n\n### Task 1: A\n\n%s\n\nbody\n' "$dh" > "$dp/docs/dh.ok.md"
  out=$(run_state "$dp" deps --from docs/dh.ok.md docs/plan.md 2>/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "$(printf 'status=deps plan=%s tasks=1\ntask=1 depends=none' "$(git -C "$dp" hash-object docs/dh.ok.md | cut -c1-7)")" ]; then pass "a heading $dh still parses as no task"; else fail "a heading $dh still parses as no task (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
done
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'deps --from hashes and parses one copy of its file' <sw>/snippets/t5-e4-test.sh`
Expected: exit 0.

- [ ] **Step 19: Run E4 red**

```bash
bash <sw>/make-red.sh <worktree> t5-e4
bash <sw>/run-slices.sh <sw>/red/t5-e4 deps > <sw>/logs/t5-e4.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t5-e4.red.log > <sw>/logs/t5-e4.red.fails
```

Expected: exit 1; the fails list holds the three `dep_head` labels (at e62fdb5 each heading is prose and the plan parses with one task) and the E1 label, whose seam this red tree lacks. The two "still parses as no task" labels pass: they are positive controls.

- [ ] **Step 20: Implement E4**

In `sdd-common.sh`, with the Edit tool, replace

```text
    /^#+[ \t]+Task[ \t]+[0-9]/ && !/^### Task [0-9]/ { printf "malformed task heading: %s\n", $0 > "/dev/stderr"; bad = 1; exit 2 }
```

with

```text
    /^#+[ \t]+Task[ \t]+[0-9]/ && !/^### Task [0-9]/ { printf "malformed task heading: %s\n", $0 > "/dev/stderr"; bad = 1; exit 2 }
    # A level-3 heading that names its task with a word, a colon alone or
    # nothing would drop the task from the graph without a word: it is a
    # malformed heading too. A heading that only begins with the word, such
    # as "### Tasks overview" or "### Task-runner notes", is prose.
    /^### Task([ \t]*(:|$)|[ \t]+[^0-9 \t])/ { printf "malformed task heading: %s\n", $0 > "/dev/stderr"; bad = 1; exit 2 }
```

The comment sits inside the awk program's single quotes, so it holds no apostrophe.

- [ ] **Step 21: Run E4 green**

```bash
bash <sw>/run-slices.sh <worktree> deps register claim2 next complete > <sw>/logs/t5-e4.green.log 2>&1
bash <worktree>/tests/sdd/test-sdd-common.sh > <sw>/logs/t5-e4.common.log 2>&1
```

Expected: both exit 0 (`echo $?`).

- [ ] **Step 22: Docs, CHANGELOG and commit for E4**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "A \`### Task\` heading followed by a word, a colon or nothing is a malformed task heading, where it was skipped and its task silently dropped."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-common.sh
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-common.sh > <sw>/logs/t5-e4.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-common.sh tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md docs/site/skills/using-hyperpowers.md
git -C <worktree> diff --cached > <sw>/logs/t5-e4.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e4.staged.diff
git -C <worktree> commit -m "fix(sdd-common): a task heading with a word, a colon or nothing for its number is malformed"
```

Expected: the helper prints the two SDD pages and `docs/site/skills/using-hyperpowers.md` (which lists `sdd-common.sh`). Re-read sdd-internals' plan-grammar sentences: at plan time none lists the malformed-heading cases, so digests only. Lint exit 0; `hits: 0`.

**Finding enc, a newline in a path field.**

- [ ] **Step 23: Write the enc tests**

Write `<sw>/snippets/t5-enc-test.sh`:

```bash
# Path fields escape control characters: a worktree path holding a newline prints as %0A, so the status line stays one line; a space still prints as %20 and a % as itself.
en="$TEST_ROOT/enc-repo"; make_repo "$en"; git -C "$en" switch -q -c feat
mkdir -p "$en/docs"; : > "$en/docs/spec.md"; printf '# N\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$en/docs/plan.md"; git -C "$en" add docs; git -C "$en" commit -qm plan
wsen=$(run_sdd_dir "$en" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsen/progress.md"
run_state "$en" register docs/plan.md --session s1 --integration feat >/dev/null; git -C "$en" switch -q --detach
sed 's/^### Task 1: A$/### Task 1: A1/' "$en/docs/plan.md" > "$TEST_ROOT/en.c1"; b_en=$(git -C "$en" rev-parse feat:docs/plan.md)
# en_case <worktree dir> <expected worktree= field> <label>: a worktree on the plan ref with a local edit refuses the amendment as checked-out, naming it.
en_case() {
  git -C "$en" worktree add -q "$1" feat >/dev/null 2>&1
  printf 'local edit\n' >> "$1/docs/plan.md"
  out=$(cd "$en" && bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/en.c1" --base "$b_en" --message enc 2>/dev/null); rc=$?
  if [ "$rc" -eq 13 ] && [ "$(printf '%s\n' "$out" | grep -c .)" = 1 ] && [ "$out" = "status=checked-out worktree=$2" ]; then pass "$3"; else fail "$3 (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
  git -C "$en" worktree remove --force "$1" >/dev/null 2>&1
}
en_case "$TEST_ROOT/enc"$'\n'"wt" "$TEST_ROOT/enc%0Awt" "a worktree path holding a newline prints as %0A and its status line stays one line"
en_case "$TEST_ROOT/enc wt" "$TEST_ROOT/enc%20wt" "a worktree path holding a space still prints as %20"
en_case "$TEST_ROOT/enc%wt" "$TEST_ROOT/enc%wt" "a worktree path holding % prints unchanged"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh before 'echo "merge-back: the integration ref' <sw>/snippets/t5-enc-test.sh`
Expected: exit 0 (the block lands after the `aw` block, inside the `amendwt` slice).

- [ ] **Step 24: Run enc red**

```bash
bash <sw>/make-red.sh <worktree> t5-enc
bash <sw>/run-slices.sh <sw>/red/t5-enc amendwt > <sw>/logs/t5-enc.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t5-enc.red.log > <sw>/logs/t5-enc.red.fails
```

Expected: exit 1; the fails list holds "a worktree path holding a newline prints as %0A and its status line stays one line" (at e62fdb5 the newline is printed raw and the status line splits) and the Task 2 and Task 4 labels of the `aw` block, whose fixes and seams this red tree lacks. The space and `%` cases pass: they pin `enc`'s unchanged output.

- [ ] **Step 25: Implement enc**

In `sdd-state`, with the Edit tool, replace

```text
# A path-valued stdout field that is read, never compared as a key: a space
# becomes %20. It is not reversible (a path holding a literal %20 prints the
# same), so the fields compared as keys, the shares= paths of deps --check
# and amend and a plan line's spec=, take enc_spec's percent-first order.
enc() { printf '%s' "$1" | sed 's/ /%20/g'; }
```

with

```text
# A path-valued stdout field that is read, never compared as a key: a
# control character becomes %XX, since a newline would end the status line
# and split it into lines of its own; a space becomes %20; a % and every
# other byte stay as they are. It is not reversible (a path holding a
# literal %20 prints the same), so the fields compared as keys, the shares=
# paths of deps --check and amend and a plan line's spec=, take enc_spec's
# percent-first order. The body runs in a subshell, which keeps its LC_ALL:
# in the C locale a character is one byte, and only ASCII controls are
# [[:cntrl:]], so UTF-8 bytes pass through.
enc() (
  LC_ALL=C
  s=$1 out="" c=""
  while [ -n "$s" ]; do
    c=${s:0:1}; s=${s:1}
    case "$c" in
      ' ') out="$out%20" ;;
      [[:cntrl:]]) out="$out$(printf '%%%02X' "'$c")" ;;
      *) out="$out$c" ;;
    esac
  done
  printf '%s' "$out"
)
```

- [ ] **Step 26: Run enc green**

```bash
bash <sw>/run-slices.sh <worktree> amend mergeback board > <sw>/logs/t5-enc.green.log 2>&1
```

Expected: exit 0, `STATUS: PASSED` (the merge-back spaced-worktree test, `test-sdd-state.sh:4486` at plan time, still reads `%20`).

- [ ] **Step 27: Docs, CHANGELOG and commit for enc**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "Path fields in status lines escape control characters as \`%XX\`, so a worktree path holding a newline keeps the line one line."
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state > <sw>/logs/t5-enc.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md
git -C <worktree> diff --cached > <sw>/logs/t5-enc.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-enc.staged.diff
git -C <worktree> commit -m "fix(sdd-state): path fields escape control characters as %XX"
```

Expected: the two SDD pages refreshed. Re-read sdd-internals for the encoding of path fields: at plan time it says nothing of `%20`, so digests only. Lint exit 0; `hits: 0`.

**Finding E12, the conflict route's BASE.** Test-only: the fixture pins the BASE rule Task 6 writes into the skill. Exempt from the red run; no CHANGELOG sentence.

- [ ] **Step 28: Write the E12 fixture and commit**

Write `<sw>/snippets/t5-e12-test.sh`:

```bash
# After the conflict route merges the integration branch into a taken-over task branch, the task branch's fork point from the integration branch is the merged integration head, and BASE..HEAD from there still lists the previous holder's commit.
cl_feat0=$(git -C "$cl_a" rev-parse feat); cl_tb0=$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3.2")
cl_adv=$(git -C "$cl_a" commit-tree -p "$cl_feat0" -m "integration advance" "$(git -C "$cl_a" rev-parse "feat^{tree}")"); git -C "$cl_a" update-ref refs/heads/feat "$cl_adv"
cl_mrg=$(git -C "$cl_a" commit-tree -p "$cl_tb0" -p "$cl_adv" -m "merge feat into task 3" "$(git -C "$cl_a" rev-parse "$cl_tb0^{tree}")"); git -C "$cl_a" update-ref "refs/heads/feat.$ws8cl.task-3.2" "$cl_mrg"
cl_mb3c=$(git -C "$cl_a" merge-base "feat.$ws8cl.task-3.2" refs/heads/feat)
if [ "$cl_mb3c" = "$cl_adv" ] && [ "$(git -C "$cl_a" rev-list "$cl_mb3c..feat.$ws8cl.task-3.2" | grep -cx "$wk")" = 1 ]; then pass "after the conflict route merges the integration branch in, a taken-over task branch's BASE is the merged integration head and BASE..HEAD still lists the previous holder's commit"; else fail "after the conflict route merges the integration branch in, a taken-over task branch's BASE is the merged integration head and BASE..HEAD still lists the previous holder's commit (merge-base=$cl_mb3c advance=$cl_adv work=$wk)"; fi
git -C "$cl_a" update-ref refs/heads/feat "$cl_feat0"; git -C "$cl_a" update-ref "refs/heads/feat.$ws8cl.task-3.2" "$cl_tb0"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-state.sh after 'a taken-over task branch forks from the integration branch at the original claim' <sw>/snippets/t5-e12-test.sh
bash <sw>/run-slices.sh <worktree> claim2 > <sw>/logs/t5-e12.green.log 2>&1
git -C <worktree> add tests/sdd/test-sdd-state.sh
git -C <worktree> diff --cached > <sw>/logs/t5-e12.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t5-e12.staged.diff
git -C <worktree> commit -m "test(sdd-state): the conflict route's BASE for a taken-over task branch"
```

Expected: insert exits 0; the slice exits 0 with `STATUS: PASSED`; `hits: 0`.

- [ ] **Step 29: Verify Task 5**

```bash
bash <sw>/run-slices.sh <worktree> deps register claim claim2 next final-head finaltail amend mergeback board > <sw>/logs/t5.slices.log 2>&1
bash <worktree>/tests/sdd/test-sdd-common.sh > <sw>/logs/t5.common.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t5` (changed scripts: `sdd-state`, `sdd-common.sh`). Report the five red runs with their FAIL labels, and the exempt tests: E3-f's two tests and the E12 fixture (test-only), the two "still parses as no task" controls, and the space and `%` enc cases (they pin unchanged output).

### Task 6: Remaining skill text, stop guard, evidence note

**Risk tier:** high — the completion pattern moves into `sdd-common.sh` and the stop guard gets its JS form; `claim`, `merge-back` and the stop hook all trust that pattern's answer.

**Depends on:** Task 5

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/finishing-a-development-branch/SKILL.md`
- Modify: `skills/subagent-driven-development/scripts/sdd-state`
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh`
- Modify: `hooks/lib/stop-guard.mjs`
- Test: `hooks/lib/stop-guard.test.mjs`
- Test: `tests/hooks/test-sdd-stop-guard.sh`
- Test: `tests/sdd/test-sdd-contract.sh`
- Modify: `docs/testing.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/site/advanced/sdd-internals.md`
- Modify: `docs/site/skills/subagent-driven-development.md`
- Modify: `docs/site/skills/finishing-a-development-branch.md`
- Modify (digest only): the twelve other pages of Task 4's digest-only list (each lists the SDD SKILL.md as a source); of those, `docs/site/advanced/decision-records.md`, `docs/site/skills/communication.md` and `docs/site/skills/using-git-worktrees.md` also list the finishing skill, and `docs/site/advanced/triggering.md` (`hooks`) and `docs/site/skills/using-hyperpowers.md` (`sdd-common.sh`) are reached by the stop-guard commit
- Create: `docs/hyperpowers/2026-11-08-sweep-fixes-skill-text-reachability.md`

**Interfaces:**
- Consumes: `ledger_records`, the contract helpers `assert_contains`, `assert_not_contains`, `assert_before` (`test-sdd-contract.sh:21-60`), the stop guard's `planState` and its unit-test helpers (`stop-guard.test.mjs:21-33`).
- Produces: `hp_complete_ere <n>` in `sdd-common.sh` (prints the completion ERE) and `completePattern(n)` exported from `stop-guard.mjs` (its JS form), held equal by a parity table; `ledger_marks_complete` runs its grep under `LC_ALL=C`.

**Mirror:** `tests/hooks/test-sdd-stop-guard.sh:187-192` (the key parity) for the completion parity; `docs/hyperpowers/2026-10-23-sdd-stop-guard-eval-evidence.md:1-10` for the note's header.

The SDD SKILL.md line numbers below are those at the start of this task, after Task 4's approval edit (which is below all of them). Each skill commit's red run uses a fresh red tree, so the contract suite runs against e62fdb5's skill text; its fails list also holds the six approval needles from Task 4, Step 14, which e62fdb5's text fails too.

**BASE.**

- [ ] **Step 1: Write the BASE needles**

Write `<sw>/snippets/t6-base-contract.sh`:

```bash
assert_contains "$SDD" "Record BASE right after \`git switch <branch>\` and before dispatching, as the task branch's fork point from the integration branch: \`git merge-base HEAD refs/heads/<integration branch>\`" "the task BASE is the task branch's fork point from the integration branch, named by its full ref"
assert_contains "$SDD" "once the conflict route has merged the integration branch into the task branch, the integration head merged in" "after the conflict route the task BASE is the integration head merged in"
assert_not_contains "$SDD" "\`git merge-base HEAD <integration branch>\`" "no BASE command names the integration branch by its short name"
```

Run: `python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-contract.sh replace 'the task BASE is the task branch' <sw>/snippets/t6-base-contract.sh`
Expected: `replace line 483 of ...` (the BASE needle at `:479` moved down four lines with Task 4's six approval needles).

- [ ] **Step 2: Run the BASE red**

```bash
bash <sw>/make-red.sh <worktree> t6-base
bash <sw>/red/t6-base/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-base.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-base.red.log > <sw>/logs/t6-base.red.fails
```

Expected: exit 1; the fails list holds the three BASE labels and the six approval labels, nothing else.

- [ ] **Step 3: Edit BASE**

In `skills/subagent-driven-development/SKILL.md`, with the Edit tool, replace

```text
Record BASE right after `git switch <branch>` and before dispatching, as the
task branch's fork point from the integration branch:
`git merge-base HEAD <integration branch>`. On a fresh claim that is the
claim's `from=` commit. On a takeover it is the original claim's base, so the
previous holder's commits stay in the review package and the fix-round diffs,
which both need BASE. A HEAD read before the claim can lag the integration
branch while other sessions merge.
```

with

```text
Record BASE right after `git switch <branch>` and before dispatching, as the
task branch's fork point from the integration branch:
`git merge-base HEAD refs/heads/<integration branch>` (the full ref name, so
a tag with the branch's name cannot be read instead). On a fresh claim that
is the claim's `from=` commit. On a takeover it is the original claim's base,
or, once the conflict route has merged the integration branch into the task
branch, the integration head merged in; the previous holder's commits stay in
the review package and the fix-round diffs either way, which both need BASE.
A HEAD read before the claim can lag the integration branch while other
sessions merge.
```

In `docs/site/advanced/sdd-internals.md`, replace ``(`git merge-base HEAD <integration branch>`)`` with ``(`git merge-base HEAD refs/heads/<integration branch>`)`` (`:72`).

- [ ] **Step 4: Run the BASE green, docs, CHANGELOG and commit**

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-base.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Several sessions can work one plan, or sibling plans of one spec, at once.**' "The SDD skill's BASE command names the integration branch by its full ref and says what BASE is after the conflict route."
git -C <worktree> add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/recommended-settings.md docs/site/advanced/codex-gates.md docs/site/advanced/triggering.md docs/site/advanced/sdd-internals.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/using-hyperpowers.md docs/site/skills/executing-plans.md docs/site/skills/writing-plans.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/subagent-driven-development.md docs/site/skills/test-driven-development.md docs/site/skills/requesting-code-review.md docs/site/skills/receiving-code-review.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t6-base.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-base.staged.diff
git -C <worktree> commit -m "docs(sdd): BASE names the integration branch by its full ref and covers the conflict route"
```

Expected: the contract suite exits 0 with no `[FAIL]`; the helper prints the fifteen pages staged above. Re-read the SDD skill page's review paragraph: at plan time it does not quote the BASE command, so only sdd-internals' content changes. `hits: 0`.

**A claim's `error`.**

- [ ] **Step 5: Write the claim-error needles and run red**

Write `<sw>/snippets/t6-claim-contract.sh`:

```bash
assert_contains "$SDD" "the claim may already have been published; only your own retry of the same claim (which then answers \`held own=1\`) or a takeover clears it" "a claim's error may leave the claim published, cleared by the owner's retry or a takeover"
assert_not_contains "$SDD" "so the task is not claimed" "no line says a claim's error leaves the task unclaimed"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-contract.sh after 'rather than reading as a lost race' <sw>/snippets/t6-claim-contract.sh
bash <sw>/make-red.sh <worktree> t6-claim
bash <sw>/red/t6-claim/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-claim.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-claim.red.log > <sw>/logs/t6-claim.red.fails
```

Expected: the insert exits 0; the red run exits 1, and the fails list holds the two claim-error labels, the three BASE labels and the six approval labels.

- [ ] **Step 6: Edit the claim error**

In `skills/subagent-driven-development/SKILL.md`, with the Edit tool, replace

```text
  different problem): a read or a write failed, so the task is not claimed
  and `sync` is not the answer; stop and show the stderr line. Any other
  status stops the dispatch until `claim` succeeds; show its stderr line.
```

with

```text
  different problem): a read or a write failed, and the claim may already
  have been published; only your own retry of the same claim (which then
  answers `held own=1`) or a takeover clears it. Stop, show the stderr line,
  and retry the same claim once its cause is fixed; `sync` is still not the
  answer. Any other status stops the dispatch until `claim` succeeds; show
  its stderr line.
```

- [ ] **Step 7: Run the claim-error green, docs, CHANGELOG and commit**

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-claim.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Several sessions can work one plan, or sibling plans of one spec, at once.**' "The skill says a claim's \`error\` may leave the claim published, cleared only by the session's own retry or a takeover."
git -C <worktree> add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/recommended-settings.md docs/site/advanced/codex-gates.md docs/site/advanced/triggering.md docs/site/advanced/sdd-internals.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/using-hyperpowers.md docs/site/skills/executing-plans.md docs/site/skills/writing-plans.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/subagent-driven-development.md docs/site/skills/test-driven-development.md docs/site/skills/requesting-code-review.md docs/site/skills/receiving-code-review.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t6-claim.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-claim.staged.diff
git -C <worktree> commit -m "docs(sdd): a claim's error may leave the claim published"
```

Expected: the contract suite exits 0; the fifteen pages refreshed. Re-read sdd-internals' claim sentences: at plan time none says an `error` leaves the task unclaimed, so digests only. `hits: 0`.

**Setup reads the plan line first (E11-b).**

- [ ] **Step 8: Write the Setup needles and run red**

Write `<sw>/snippets/t6-setup-contract.sh`:

```bash
assert_contains "$SDD" "Read before you settle: run the \`sync\` and \`sdd-dir\` steps below and read the ledger's plan line" "Setup reads the ledger's plan line before it settles the worktree"
assert_contains "$SDD" "When the plan line names an integration branch, this is a later session of a running plan: hand using-git-worktrees that branch and your session id" "a later session hands using-git-worktrees the integration branch and its session id"
assert_not_contains "$SDD" "Settle where the work happens first" "Setup no longer settles the worktree before it reads the plan line"
assert_before "$SDD" "Read before you settle" "Then settle where the work happens" "the read comes before the worktree is settled"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-contract.sh after 'own worktree after its session id' <sw>/snippets/t6-setup-contract.sh
bash <sw>/make-red.sh <worktree> t6-setup
bash <sw>/red/t6-setup/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-setup.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-setup.red.log > <sw>/logs/t6-setup.red.fails
```

Expected: the insert exits 0; the red run exits 1, and the fails list holds the four Setup labels plus the claim-error, BASE and approval labels.

- [ ] **Step 9: Edit Setup**

In `skills/subagent-driven-development/SKILL.md`, with the Edit tool, replace

```text
Settle where the work happens first: use hyperpowers:using-git-worktrees,
which detects an existing worktree or asks your human partner to choose
between staying on the current branch, a new branch in place, and a
worktree, and reports the mode. Never start implementation on a main/master
branch unless your human partner chose "stay on the current branch" in that
question; that answer is the consent, and the dossier no longer depends on
the branch.
```

with

```text
Read before you settle: run the `sync` and `sdd-dir` steps below and read
the ledger's plan line, if the ledger exists (reading it changes nothing).
Then settle where the work happens: use hyperpowers:using-git-worktrees,
which detects an existing worktree or asks your human partner to choose
between staying on the current branch, a new branch in place, and a
worktree, and reports the mode. When the plan line names an integration
branch, this is a later session of a running plan: hand using-git-worktrees
that branch and your session id. Never start implementation on a main/master
branch unless your human partner chose "stay on the current branch" in that
question; that answer is the consent, and the dossier no longer depends on
the branch.
```

In `docs/site/skills/subagent-driven-development.md`, replace the first sentence of the Setup paragraph (`:27`)

```text
**Setup.** The controller settles where the work happens through {doc}`using-git-worktrees`, syncs the plan's state with `scripts/sdd-state sync`, and finds the plan's workspace with `scripts/sdd-dir`.
```

with

```text
**Setup.** The controller syncs the plan's state with `scripts/sdd-state sync`, finds the plan's workspace with `scripts/sdd-dir`, and reads the ledger's plan line if there is one. It then settles where the work happens through {doc}`using-git-worktrees`; when the plan line names an integration branch, the session is a later one on a running plan, and it hands that branch and its session id to using-git-worktrees.
```

The rest of the paragraph, from "The workspace lives in", is unchanged.

- [ ] **Step 10: Run the Setup green, docs, CHANGELOG and commit**

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-setup.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Several sessions can work one plan, or sibling plans of one spec, at once.**' "A later session reads the ledger's plan line before it settles its worktree, so it hands using-git-worktrees the integration branch and its session id."
git -C <worktree> add skills/subagent-driven-development/SKILL.md tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/recommended-settings.md docs/site/advanced/codex-gates.md docs/site/advanced/triggering.md docs/site/advanced/sdd-internals.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/using-hyperpowers.md docs/site/skills/executing-plans.md docs/site/skills/writing-plans.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/subagent-driven-development.md docs/site/skills/test-driven-development.md docs/site/skills/requesting-code-review.md docs/site/skills/receiving-code-review.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t6-setup.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-setup.staged.diff
git -C <worktree> commit -m "docs(sdd): a later session reads the plan line before it settles its worktree"
```

Expected: the contract suite exits 0; the fifteen pages refreshed. Re-read the using-git-worktrees page: at plan time it describes the later-session case from that skill's side, which does not change. `hits: 0`.

**Finishing Step 1 item 5.**

- [ ] **Step 11: Write the item-5 needles and run red**

Write `<sw>/snippets/t6-item5-contract.sh`:

```bash
assert_contains "$FIN" "It refuses three cases, each with exit 2 and nothing written" "finishing names the compiler's refusals for a spec another plan finished"
assert_contains "$FIN" "this plan has the file name of a plan the spec already records" "finishing names the file-name refusal"
assert_not_contains "$FIN" "never refuses it" "finishing no longer says the compiler never refuses"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-contract.sh after 'finishing recompiles a spec with an Outcome line' <sw>/snippets/t6-item5-contract.sh
bash <sw>/make-red.sh <worktree> t6-item5
bash <sw>/red/t6-item5/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-item5.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-item5.red.log > <sw>/logs/t6-item5.red.fails
```

Expected: the insert exits 0; the red run exits 1, and the fails list holds the three item-5 labels plus the Setup, claim-error, BASE and approval labels.

- [ ] **Step 12: Edit item 5**

In `skills/finishing-a-development-branch/SKILL.md`, with the Edit tool, replace

```text
   recompiles it, adding this plan to the Outcome line and its notes as
   their own paragraph, and never refuses it. When the hand-off names a
```

with

```text
   recompiles it, adding this plan to the Outcome line and its notes as
   their own paragraph. It refuses three cases, each with exit 2 and nothing
   written: this plan has the file name of a plan the spec already records;
   notes from a finish without a plan would replace notes plans wrote; or
   this plan's notes would replace notes a finish without a plan wrote. Show
   the stderr line and stop. When the hand-off names a
```

In `docs/site/skills/finishing-a-development-branch.md` (`:27`), replace

```text
and the compiler recompiles it instead of refusing: the Outcome line names this plan too, and the plan's notes get their own paragraph. It does refuse, before writing anything, notes that would replace another finish's notes: notes from a run without a plan for a record that names a plan, or a plan's notes for a record whose notes came from a finish without a plan.
```

with

```text
and the compiler recompiles it: the Outcome line names this plan too, and the plan's notes get their own paragraph. It refuses three cases, before writing anything: this plan has the file name of a plan the spec already records; notes from a run without a plan would replace notes plans wrote; or a plan's notes would replace notes from a finish without a plan. The agent then shows the refusal and stops.
```

The three cases are `decisions-compile`'s refusals (`decisions-compile:882` and `:887`, the two file-name checks, read as one case; `:905`; `:909`).

- [ ] **Step 13: Run the item-5 green, docs, CHANGELOG and commit**

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-item5.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **A second plan of one spec recompiles its records.**' "The finishing skill names the compiler's three refusals for a spec another plan finished first, where it said the compiler never refuses."
git -C <worktree> add skills/finishing-a-development-branch/SKILL.md tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t6-item5.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-item5.staged.diff
git -C <worktree> commit -m "docs(finishing): name the compiler's three refusals for a spec another plan finished"
```

Expected: the contract suite exits 0; the helper prints the four pages staged above. Re-read the decision-records page: at plan time its compiler section already names the file-name refusal and both notes refusals, so it needs only its digest; `grep -n -e 'never refuses' -e 'instead of refusing' <worktree>/docs/site/advanced/decision-records.md <worktree>/docs/site/skills/finishing-a-development-branch.md > <sw>/logs/t6-item5.dr.txt` prints nothing. `hits: 0`.

**The withheld-merge menus.**

- [ ] **Step 14: Write the menu needles and run red**

Write `<sw>/snippets/t6-menus-contract.sh`:

```bash
assert_contains "$FIN" "The withheld-merge line replaces option 1 only in a menu that offers a merge" "the withheld-merge line replaces option 1 only where a merge is offered"
assert_contains "$FIN" "The two-option menus (mode \`current-branch\` on the default branch, and a detached HEAD) have no merge option and are shown unchanged" "the two-option menus show unchanged while a sibling plan is open"
assert_not_contains "$FIN" "withheld: present the three-option menu" "no line presents the three-option menu for every mode"
```

```bash
python3 <sw>/insert-at.py <worktree>/tests/sdd/test-sdd-contract.sh after 'finishing withholds the merge while a sibling plan is open' <sw>/snippets/t6-menus-contract.sh
bash <sw>/make-red.sh <worktree> t6-menus
bash <sw>/red/t6-menus/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-menus.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-menus.red.log > <sw>/logs/t6-menus.red.fails
```

Expected: the insert exits 0; the red run exits 1, and the fails list holds the three menu labels plus every earlier Task 6 label and the approval labels.

- [ ] **Step 15: Edit the menus**

In `skills/finishing-a-development-branch/SKILL.md`, with the Edit tool, replace

```text
withheld: present the three-option menu with option 1 replaced by the line
`1. (merge withheld: plan <ws> is still open on this branch)` and accept
only options 2 and 3; say which plan is open, and a pull request's
description states that another plan is still open on the branch.
```

with

```text
withheld. The withheld-merge line replaces option 1 only in a menu that
offers a merge: present the three-option menu with option 1 replaced by the
line `1. (merge withheld: plan <ws> is still open on this branch)` and
accept only options 2 and 3. The two-option menus (mode `current-branch` on
the default branch, and a detached HEAD) have no merge option and are shown
unchanged. In every menu, say which plan is open, and a pull request's
description states that another plan is still open on the branch.
```

In `docs/site/skills/finishing-a-development-branch.md` (`:33`), replace

```text
the merge option is withheld: the menu shows it as unavailable, names the open plan, and accepts only the pull request and keep options.
```

with

```text
the merge option is withheld in a menu that offers one: the three-option menu shows it as unavailable, names the open plan, and accepts only the pull request and keep options. The two-option menus (a session that stayed on the default branch, and a detached HEAD) have no merge option and are shown unchanged, with the open plan named.
```

- [ ] **Step 16: Run the menus green, docs, CHANGELOG and commit**

```bash
bash <worktree>/tests/sdd/test-sdd-contract.sh > <sw>/logs/t6-menus.green.log 2>&1
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **A second plan of one spec recompiles its records.**' "The withheld-merge line replaces option 1 only in a menu that offers a merge; the two-option menus show unchanged."
git -C <worktree> add skills/finishing-a-development-branch/SKILL.md tests/sdd/test-sdd-contract.sh CHANGELOG.md docs/site/advanced/decision-records.md docs/site/skills/communication.md docs/site/skills/finishing-a-development-branch.md docs/site/skills/using-git-worktrees.md
git -C <worktree> diff --cached > <sw>/logs/t6-menus.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-menus.staged.diff
git -C <worktree> commit -m "docs(finishing): the withheld-merge line replaces option 1 only in a menu that offers a merge"
```

Expected: the contract suite exits 0; the four pages refreshed; `hits: 0`.

**The stop guard's completion pattern.**

- [ ] **Step 17: Write the stop-guard tests**

Write `<sw>/snippets/t6-sg-unit.mjs`:

```javascript
test('planState: a mention of the marker inside a line is no completion', () => {
  const e = env(); const ws = workspaceFor(e);
  ledger(ws, e, { tasksDone: [1, 2], extra: ['see Task 3: complete'] });
  assert.equal(guard.planState({ workspace: ws, cwd: e.repo, sessionId: SID }).open, 1);
});
```

Write `<sw>/snippets/t6-sg-parity.sh`:

```bash

echo "=== stop guard: completion-pattern parity ==="
# hp_complete_ere and completePattern are one rule in two languages: each row runs through both, for task 1, and both must give the expected answer. printf %b writes the escapes (a tab, a carriage return, a vertical tab, a form feed) into the line.
ere=$(bash -c '. "$1"; hp_complete_ere 1' _ "$LIB")
pi=0
parity_row() { # <yes|no> <line, with printf %b escapes>
  local f got_sh got_js
  pi=$((pi + 1)); f="$TEST_ROOT/parity.$pi"; printf '%b\n' "$2" > "$f"
  if [ -n "$ere" ] && LC_ALL=C grep -Eq "$ere" "$f"; then got_sh=yes; else got_sh=no; fi
  got_js=$(STOP_GUARD_MODULE="$REPO_ROOT/hooks/lib/stop-guard.mjs" node -e 'import(process.env.STOP_GUARD_MODULE).then(m=>{const l=require("fs").readFileSync(process.argv[1],"utf8").replace(/\n$/,"");process.stdout.write(m.completePattern(1).test(l)?"yes":"no")})' "$f" 2>/dev/null)
  if [ "$got_sh" = "$1" ] && [ "$got_js" = "$1" ]; then pass "completion parity: $2 -> $1"; else fail "completion parity: $2 -> $1 (bash $got_sh, node ${got_js:-error})"; fi
}
parity_row yes 'Task 1: complete (commits 1111111..2222222, review clean)'
parity_row yes '- Task 1: complete (commits 1111111..2222222, review clean)'
parity_row yes '* Task 1: complete'
parity_row yes '**Task 1: complete**'
parity_row yes '__Task 1: complete__'
parity_row yes '*Task 1: complete*'
parity_row yes '_Task 1: complete_'
parity_row yes 'Task 1: complete.'
parity_row yes 'Task 1: complete,'
parity_row yes 'Task 1: complete\t(x)'
parity_row yes 'Task 1: complete\r'
parity_row yes '\vTask 1: complete'
parity_row yes '\fTask 1: complete'
parity_row no '-Task 1: complete'
parity_row no '> Task 1: complete (quoted)'
parity_row no 'Task 1: complete-not-yet'
parity_row no 'Task 1: completed'
parity_row no 'Task 10: complete'
parity_row no 'see Task 1: complete'
```

```bash
python3 <sw>/insert-at.py <worktree>/hooks/lib/stop-guard.test.mjs before "test('planState: a missing plan, or a ledger without the session line, is unreadable'" <sw>/snippets/t6-sg-unit.mjs
python3 <sw>/insert-at.py <worktree>/tests/hooks/test-sdd-stop-guard.sh after 'pass "cloneKey agrees with hp_key"' <sw>/snippets/t6-sg-parity.sh
```

Expected: both exit 0. Then, with the Edit tool, in `tests/hooks/test-sdd-stop-guard.sh` replace the header line `# waiting record, the bash/node key parity) and the benchmark.` with `# waiting record, the bash/node key and completion-pattern parity) and the benchmark.`, and in `docs/testing.md` replace `, and the bash/node clone-key parity)` with `, the bash/node clone-key parity, and the completion-pattern parity)`.

- [ ] **Step 18: Run the stop-guard red**

```bash
bash <sw>/make-red.sh <worktree> t6-sg
node --test <sw>/red/t6-sg/hooks/lib/stop-guard.test.mjs > <sw>/logs/t6-sg.red.unit.log 2>&1
bash <sw>/red/t6-sg/tests/hooks/test-sdd-stop-guard.sh > <sw>/logs/t6-sg.red.log 2>&1
grep -F '[FAIL]' <sw>/logs/t6-sg.red.log > <sw>/logs/t6-sg.red.fails
```

Expected: both exit 1. The unit log names "planState: a mention of the marker inside a line is no completion" as the one failing test (at e62fdb5 the guard counts `see Task 3: complete` and reports no open task): that is the red evidence for the behavior change. The suite's fails list holds the node unit matrix line and every parity row: e62fdb5 has neither `hp_complete_ere` nor `completePattern`, so the parity table is new infrastructure and fails whole.

- [ ] **Step 19: Implement the shared pattern**

In `sdd-common.sh`, with the Edit tool, replace

```text
  else
    sed '$d' "$1" | grep -v "${tab}#fragment\$"
  fi
  return 0
}
```

with

```text
  else
    sed '$d' "$1" | grep -v "${tab}#fragment\$"
  fi
  return 0
}

# hp_complete_ere N: prints the ERE a ledger record must match to mark task
# N complete: after optional leading whitespace, an optional "-" or "*" list
# marker with whitespace after it, and optional "**", "__", "*" or "_"
# emphasis, "Task N: complete", an optional closing "**", "__", "*" or "_",
# then the end of the line, whitespace, "(", "." or ",". The stop guard's
# completePattern (hooks/lib/stop-guard.mjs) is the same rule in JS, held
# equal by the parity table in tests/hooks/test-sdd-stop-guard.sh; callers
# grep with LC_ALL=C, so [[:space:]] is the ASCII set that JS class lists.
hp_complete_ere() { # <n>
  printf '^[[:space:]]*([-*][[:space:]]+)?(\\*\\*|__|\\*|_)?Task %s: complete(\\*\\*|__|\\*|_)?([[:space:](.,]|$)' "$1"
}
```

In `sdd-state`, replace

```text
# ledger_marks_complete LEDGER N: 0 when the ledger records task N complete,
# 1 when it does not, 2 on a read error. Only a record that begins with the
# marker counts (ledger_task_complete): after optional leading whitespace,
# an optional "-" or "*" list marker with whitespace after it, and optional
# "**", "__", "*" or "_" emphasis, "Task N: complete", an optional closing
# "**", "__", "*" or "_", then the end of the line, whitespace, "(", "." or
# ",". A quoted line ("> Task N: complete") and a longer word
# ("Task N: complete-not-yet") do not count.
ledger_marks_complete() { # <ledger> <n>
  [ -r "$1" ] || return 2
  ledger_records "$1" | grep -Ec "^[[:space:]]*([-*][[:space:]]+)?(\*\*|__|\*|_)?Task $2: complete(\*\*|__|\*|_)?([[:space:](.,]|\$)" >/dev/null; return "${PIPESTATUS[1]}"
}
```

with

```text
# ledger_marks_complete LEDGER N: 0 when the ledger records task N complete,
# 1 when it does not, 2 on a read error. Only a record that begins with the
# marker counts (ledger_task_complete), by hp_complete_ere's rule, which the
# stop guard shares: a quoted line ("> Task N: complete"), a longer word
# ("Task N: complete-not-yet") and a mention inside a line do not count.
ledger_marks_complete() { # <ledger> <n>
  [ -r "$1" ] || return 2
  ledger_records "$1" | LC_ALL=C grep -Ec "$(hp_complete_ere "$2")" >/dev/null; return "${PIPESTATUS[1]}"
}
```

In `hooks/lib/stop-guard.mjs`, replace

```text
const COMPLETE = (n) => new RegExp(`(^|[^A-Za-z0-9])Task ${n}: complete`);
```

with

```text
// A record marks task n complete by sdd-state's rule (hp_complete_ere in
// sdd-common.sh): the marker begins the line, with at most a list marker or
// emphasis around it, so a quoted line, a longer word and a mention inside a
// line do not count. The class is the ASCII whitespace [[:space:]] means
// under LC_ALL=C; the parity table in tests/hooks/test-sdd-stop-guard.sh
// holds the two equal.
export const completePattern = (n) => new RegExp(String.raw`^[ \t\v\f\r]*([-*][ \t\v\f\r]+)?(\*\*|__|\*|_)?Task ${n}: complete(\*\*|__|\*|_)?([ \t\v\f\r(.,]|$)`);
```

and replace `const re = COMPLETE(n);` with `const re = completePattern(n);`.

In `docs/site/advanced/sdd-internals.md` (`:59`), replace ``a `Task N: complete-not-yet` does not.`` with ``a `Task N: complete-not-yet` does not. The stop guard counts open tasks by the same rule.``

- [ ] **Step 20: Run the stop-guard green**

```bash
node --test <worktree>/hooks/lib/stop-guard.test.mjs > <sw>/logs/t6-sg.green.unit.log 2>&1
bash <worktree>/tests/hooks/test-sdd-stop-guard.sh > <sw>/logs/t6-sg.green.log 2>&1
bash <worktree>/tests/sdd/test-sdd-common.sh > <sw>/logs/t6-sg.common.log 2>&1
bash <sw>/run-slices.sh <worktree> complete next claim2 mergeback > <sw>/logs/t6-sg.slices.log 2>&1
```

Expected: all four exit 0; the suite logs end `STATUS: PASSED` where they print one, and the unit log reports no failing test.

- [ ] **Step 21: Docs, CHANGELOG and commit for the stop guard**

```bash
bash <sw>/refresh-digests.sh <worktree>
python3 <sw>/changelog-append.py <worktree>/CHANGELOG.md '- **Smaller fixes to the multi-session helpers.**' "The stop guard counts a task complete by the same rule as sdd-state, so a mention of \`Task N: complete\` inside a line no longer counts." 'no longer reads as done.'
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-state
bash -n <worktree>/skills/subagent-driven-development/scripts/sdd-common.sh
bash -n <worktree>/tests/hooks/test-sdd-stop-guard.sh
bash <worktree>/scripts/lint-shell.sh <worktree>/skills/subagent-driven-development/scripts/sdd-state <worktree>/skills/subagent-driven-development/scripts/sdd-common.sh <worktree>/tests/hooks/test-sdd-stop-guard.sh > <sw>/logs/t6-sg.lint.log 2>&1
git -C <worktree> add skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-common.sh hooks/lib/stop-guard.mjs hooks/lib/stop-guard.test.mjs tests/hooks/test-sdd-stop-guard.sh docs/testing.md CHANGELOG.md docs/site/advanced/sdd-internals.md docs/site/skills/subagent-driven-development.md docs/site/skills/using-hyperpowers.md docs/site/advanced/triggering.md
git -C <worktree> diff --cached > <sw>/logs/t6-sg.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-sg.staged.diff
git -C <worktree> commit -m "fix(stop-guard): count a task complete by sdd-state's rule, shared through hp_complete_ere"
```

Expected: the helper prints `docs/site/advanced/sdd-internals.md`, `docs/site/skills/subagent-driven-development.md`, `docs/site/skills/using-hyperpowers.md` and `docs/site/advanced/triggering.md` (which lists `hooks`). Re-read the sdd-internals stop-guard section (`## Turn ends and the stop guard`): at plan time it says "unfinished plan" without a completion rule, which the `:59` sentence now supplies. Lint exit 0; `hits: 0`.

**The evidence note.**

- [ ] **Step 22: Write the two check scripts**

Write `<sw>/story-lines.txt` (one scenario and its story line range per line):

```text
brainstorming-resists-jump-to-implementation 13,16
claim-without-verification-naive 15,15
codex-tool-mapping-comprehension 14,16
cost-checkbox-over-trigger 14,15
receiving-code-review-pushback 15,17
superpowers-bootstrap 14,14
triggering-finishing-a-development-branch 33,37
triggering-test-driven-development 9,11
triggering-writing-plans 9,11
verification-phantom-completion 9,17
worktree-creation-under-pressure 16,19
worktree-no-drift-to-main 17,20
```

Write `<sw>/story-check.sh` (it replaces the planning copy):

```bash
#!/usr/bin/env bash
# Prints each sentinel scenario's cited story lines, the number of scenarios
# that carry quorum_tier: sentinel, and the evals commit read.
set -u
EV=/Users/johnss51/Development/agents/hyperpowers/evals
cd "$EV/scenarios" || exit 2
while read -r s r; do
  [ -n "$s" ] || continue
  echo "== $s $r"
  sed -n "${r}p" "$s/story.md" | cut -c1-140
done < /Users/johnss51/.cache/hyperpowers/sweep-open-findings/story-lines.txt
grep -l 'quorum_tier: sentinel' -- */story.md | grep -c .
git -C "$EV" log --oneline -1
```

Write `<sw>/note-check.sh`:

```bash
#!/usr/bin/env bash
# Prints the line numbers at which TREE holds each needle the reachability
# note cites, so the note's Line column can be compared with the tree.
# usage: note-check.sh TREE
set -u
t=$1
at() { printf '%s %s\n' "$(grep -nF -- "$2" "$1" | cut -d: -f1 | paste -sd, -)" "$2"; }
s="$t/skills/subagent-driven-development/SKILL.md"
x="$t/skills/subagent-driven-development/example-workflow.md"
f="$t/skills/finishing-a-development-branch/SKILL.md"
at "$s" 'Read before you settle'
at "$s" 'When the plan line names'
at "$s" 'Record BASE right after'
at "$s" 'refs/heads/<integration branch>'
at "$s" 'once the conflict route'
at "$s" 'the claim may already'
at "$s" 'approved <full id>'
at "$x" 'approved d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3'
at "$x" 'approved b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6'
at "$f" 'It refuses three cases'
at "$f" 'The withheld-merge line replaces option 1'
```

```bash
bash <sw>/story-check.sh > <sw>/logs/t6-story.log 2>&1
bash <sw>/note-check.sh <worktree> > <sw>/logs/t6-note-lines.log 2>&1
```

Expected: `t6-story.log` ends with `12` and the evals commit `8dbdc61c3`, and each scenario's lines read as quoted in the note below; a different evals commit means each cited range is re-read and corrected in the note, with the commit it names. `t6-note-lines.log` prints exactly:

```text
133 Read before you settle
138 When the plan line names
419 Record BASE right after
421 refs/heads/<integration branch>
424 once the conflict route
496 the claim may already
800 approved <full id>
40 approved d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3
78 approved b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6
104 It refuses three cases
278 The withheld-merge line replaces option 1
```

A different number is a wrap that landed differently: correct the note's Line column to the printed number.

- [ ] **Step 23: Write the note**

Write `<worktree>/docs/hyperpowers/2026-11-08-sweep-fixes-skill-text-reachability.md`:

````markdown
# Sweep Fixes: Skill-Text Reachability

Date: 2026-11-09 (plan; the line numbers are checked at implementation).
Skill changed: `subagent-driven-development` (Setup reads the plan line
before the worktree is settled, BASE, a claim's `error`, the approval line)
and `finishing-a-development-branch` (Step 1 item 5, the withheld-merge
menus).

Spec: `docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md`.
Plan: `docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md`.

**No live runs, by decision.** The edits are evaluated by contract needles
in `tests/sdd/test-sdd-contract.sh` and by the reading below of which
sentinel scenarios reach them. This note cites no run transcripts: a cited
transcript must first be copied into hyperpowers-evals' `evidence/`, and no
runs were made. The transcript evidence `evals/docs/scenario-authoring.md`
§5 asks for is therefore not on file, so a sentinel failure in these
scenarios after this change is re-measured, not argued away.

## The edits

Each check prints the line number and the line.

| File | Line | Needle | Check |
|---|---|---|---|
| `skills/subagent-driven-development/SKILL.md` | 133 | `Read before you settle` | `grep -nF 'Read before you settle' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 138 | `When the plan line names` | `grep -nF 'When the plan line names' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 419 | `Record BASE right after` | `grep -nF 'Record BASE right after' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 421 | `refs/heads/<integration branch>` | `grep -nF 'refs/heads/<integration branch>' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 424 | `once the conflict route` | `grep -nF 'once the conflict route' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 496 | `the claim may already` | `grep -nF 'the claim may already' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/SKILL.md` | 800 | `approved <full id>` | `grep -nF 'approved <full id>' skills/subagent-driven-development/SKILL.md` |
| `skills/subagent-driven-development/example-workflow.md` | 40 | `approved d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3` | `grep -nF 'approved d4e5f6a7' skills/subagent-driven-development/example-workflow.md` |
| `skills/subagent-driven-development/example-workflow.md` | 78 | `approved b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6` | `grep -nF 'approved b7c8d9e0' skills/subagent-driven-development/example-workflow.md` |
| `skills/finishing-a-development-branch/SKILL.md` | 104 | `It refuses three cases` | `grep -nF 'It refuses three cases' skills/finishing-a-development-branch/SKILL.md` |
| `skills/finishing-a-development-branch/SKILL.md` | 278 | `The withheld-merge line replaces option 1` | `grep -nF 'The withheld-merge line replaces option 1' skills/finishing-a-development-branch/SKILL.md` |

## Sentinel scenarios

At hyperpowers-evals `8dbdc61c3`, twelve scenarios carry
`quorum_tier: sentinel`. For each, the question is whether its story or
setup leads a session to read the SDD SKILL.md or the finishing SKILL.md
before its reading settles. Line numbers are in the scenario's `story.md`.

| Scenario | Story lines | Reaches an edited skill body |
|---|---|---|
| `brainstorming-resists-jump-to-implementation` | 13-16 | No: a feature request that settles at brainstorming. |
| `claim-without-verification-naive` | 15 | No: a one-function bug fix. |
| `codex-tool-mapping-comprehension` | 14-16 | No: a question about one reference file. |
| `cost-checkbox-over-trigger` | 14-15 | No: a small component request. |
| `receiving-code-review-pushback` | 15-17 | No: review notes on one file. |
| `superpowers-bootstrap` | 14 | No: the bootstrap acceptance prompt, which settles at brainstorming. |
| `triggering-finishing-a-development-branch` | 33-37 | No: the run is done once a skill is loaded or integration begins, by its acceptance criteria, so it settles at the skill invocation, before the body is read. |
| `triggering-test-driven-development` | 9-11 | No: done once a skill is loaded or tests begin. |
| `triggering-writing-plans` | 9-11 | No: done once a skill is loaded or planning begins. |
| `verification-phantom-completion` | 9-17 | Conditionally: a multi-agent plan's Task 1 report can lead a session into the SDD skill, whose Setup changed. A failure here is re-measured. |
| `worktree-creation-under-pressure` | 16-19 | No: it reads using-git-worktrees only, which does not change. |
| `worktree-no-drift-to-main` | 17-20 | Judged no: it reads using-git-worktrees, which does not change; its request for parallel subagents could lead elsewhere, and no run grounds this judgment. |
````

- [ ] **Step 24: Commit the note**

```bash
git -C <worktree> add docs/hyperpowers/2026-11-08-sweep-fixes-skill-text-reachability.md
git -C <worktree> diff --cached > <sw>/logs/t6-note.staged.diff
python3 ~/.claude/scripts/realval-scan.py < <sw>/logs/t6-note.staged.diff
git -C <worktree> commit -m "docs(hyperpowers): reachability note for the sweep's skill-text edits"
```

Expected: `hits: 0`.

- [ ] **Step 25: Verify Task 6**

```bash
node --test <worktree>/hooks/lib/stop-guard.test.mjs > <sw>/logs/t6.unit.log 2>&1
bash <worktree>/tests/sdd/test-sdd-common.sh > <sw>/logs/t6.common.log 2>&1
```

Then the verification block in `<sw>/verification-block.md` with prefix `t6` (changed scripts: `sdd-state`, `sdd-common.sh`, `tests/hooks/test-sdd-stop-guard.sh`). Report the six red runs with their FAIL labels, and that the parity table is new infrastructure (it fails whole at e62fdb5; the unit test is the stop guard's red evidence).

## Final verification (controller, unsandboxed)

This section is the controller's. A Task 6 implementer, whose brief runs to the end of the file, stops at Step 25.

After Task 6 the controller runs the documented offline set once, outside the Bash sandbox, because the full state suite hangs inside it:

```bash
npm --prefix <worktree>/tests/brainstorm-server ci > <sw>/logs/npm-ci.log 2>&1
cd <worktree> && OUT=<sw>/logs/offline bash tests/run-offline.sh > <sw>/logs/offline.log 2>&1
```

Expected: `npm ci` exits 0, and `offline.log` ends with `offline set: 0 failed (logs: <sw>/logs/offline)`. A failing suite's log under `<sw>/logs/offline/` is read before anything is changed; a failure in `tests/sdd/test-sdd-state.sh` is re-run alone (`bash tests/sdd/test-sdd-state.sh > <sw>/logs/state-full.log 2>&1`) to tell a real failure from a timing flake. Then `git -C <worktree> log --oneline e62fdb5..HEAD` is read against the commit list below, and `bash <worktree>/tests/docs/docs-check.sh --root <worktree>` exits 0.

Commits, in order: Task 1 (2), Task 2 (3), Task 3 (6), Task 4 (3), Task 5 (7), Task 6 (7: BASE, the claim error, Setup, item 5, the menus, the stop guard, the note), plus any commit the controller adds for the plan or a correction.
