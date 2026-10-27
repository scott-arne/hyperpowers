# Parallel Development Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** docs/hyperpowers/specs/2026-10-27-parallel-development-design.md

**Goal:** Let several Claude sessions work one plan, or sibling plans of one spec, at the same time on one machine: plans declare task dependencies, sessions claim only ready tasks, each task merges back into one integration branch after its gate, a board shows who waits on what, and the final train is claimed.

**Architecture:** Everything is state the dossier already reads and writes: `**Depends on:**` lines in the plan, parsed from the plan ref's head by one function in `sdd-common.sh`; claim directories that now carry the task branch; per-session `waiting/`, `activity/`, `merges/` and `amends/` records beside the ledger; a branch lease beside the repository lock. `sdd-state` gains `deps`, `register`, `next`, `wait`, `board`, `merge-back`, `amend`, `lease` and `claim final`, and `finish` takes a session. Merges use the same `merge-tree`, `commit-tree` and compare-and-swap `update-ref` plumbing `sync` uses for the state branch. The skill text makes a session register, take what `next` offers, merge back, post when blocked, and claim `final`.

**Tech Stack:** bash (3.2-compatible, `set -uo pipefail` in `sdd-state`), node for atomic renames only, git 2.31 everywhere and 2.38 for `merge-back` and `amend`; tests are the existing bash suites.

## Global Constraints

- Spec floors: git 2.31 for every subcommand; `merge-back` and `amend` require git 2.38 (`merge-tree --write-tree`) and refuse an older git by name with `status=error`, in the shape of the pin's 2.31 refusal in `cmd_sync` (`skills/subagent-driven-development/scripts/sdd-state:1626`). No new dependency; node is already required on the state paths.
- Output grammar: one `status=` line on stdout per subcommand, except `board` (status line, then its table), `deps` (status line, then one `task=` line per task) and the refusals of `amend` and `deps --check` (status line, then one `conflict ...` line per undeclared overlap). Every path-valued field goes through `enc` (`sdd-state:82`).
- No subcommand deletes a code branch. The controller deletes its own task branch after `merge-back` published it; the board lists leftovers; deletion of a leftover is the human partner's.
- Every multi-step write is idempotent on retry and has a crash seam (`HYPERPOWERS_TEST_CRASH_AT`, exit 99 after `hp_unlock`, as the existing values do) after each irreversible step named in the spec; new seam values are listed in each task and are the only new seams: `claim-after-rename`, `claim-after-branch`, `merge-back-after-record`, `merge-back-after-swap`, `merge-back-after-ledger`, `amend-after-swap`; new `HYPERPOWERS_TEST_PAUSE_AT` values: `register-before-write`, `lease-before-close`, `lock-pair-between`; two new `HYPERPOWERS_TEST_WRITER_AT` values, `merge-back-before-swap:<sha>` (inside merge-back, after the merge record and before the swap, the integration ref is moved to `<sha>`, once) and `amend-before-swap:<sha>` (inside amend, after the amendment record and before the swap, the plan ref is moved to `<sha>`, once). A pause seam creates `<checkout>/.<value>-paused` and waits while `<checkout>/.<value>-pause` exists, as `sync-before-apply` does (`sdd-state`, grep `sync-paused`).
- Names: task branch `<integration>.<ws8>.task-<N>` and `<integration>.<ws8>.task-<N>.<k>` after a takeover (`k` from 2); lease file `<key>.final-<ref12>` where `<ref12>` is the first twelve hex characters of `git hash-object --stdin` over the full ref name `refs/heads/<integration>`; records `plans/<ws>/waiting/<sid>`, `plans/<ws>/activity/<sid>`, `plans/<ws>/merges/task-<N>`, `plans/<ws>/amends/<blob sha>`; the plan line `plan: integration <branch> code-root <sha7> plan-ref <ref> plan-root <sha7> spec <path>`; the ledger lines `Task <N>: branch <ref> from <sha7>`, `Task <N>: approved <sha7>`, `Task <N>: merged <sha7> into <branch> (from <sha7>)`, `plan: amended <blob sha7> by <sid>: <subject>`, `scan: accepted-overlap tasks=<a>,<b> path=<p>` (or `interface=<name>`).
- Records: a claim's owner file holds `session=`, `worktree=`, `checkout=` (the session's checked-out branch, `detached@<sha7>` when none), `host=`, `time=`, and for a task claim `branch=<task ref>` and `from=<sha>`, the task ref under `branch=` as the spec names it; the lease holds `session=`, `host=`, `plan=<ws>`, `branch=<integration>`, `time=`, `closing=0|1`; a board session row carries `host=` and `silence=<seconds|none>` beside `quiet-since=`, and `board --repo` prints `lease` rows after its plan rows.
- Exit codes added: 7 `blocked`; 8 `conflict`; 9 `wrong-branch`, `spec-branch-mismatch` (beside the existing `wrong-repo`); 11 `not-holder`, `no-final-claim`; 12 `not-approved`; 13 `checked-out`; 14 `stale`; 15 `branch-closing`, `sibling-open`. The existing 4 (`held`), 2 (usage, internal, `invalid`) and 1 (`conflicts` from `deps --check` and `amend`) are reused as the spec states.
- Lock order: two repositories' locks are taken through `hp_lock_pair`, lower `hp_key` first; `hp_unlock` releases both. `register`, `claim` whenever the ledger has a plan line (`final` included), `lease` and `merge-back` hold the pair; `amend` writes only the plan ref and holds the plan repository's lock; no caller enters `hp_lock_pair` holding a lock (Task 2 Step 1 is the audit).
- Code repository: every subcommand that takes `--code-repo` (`deps`, `register`, `claim`, `next`, `lease`, `amend`, `merge-back`, `board`, `finish`) resolves it through `code_repo_arg <value> <ledger>` unconditionally (an omitted option means the cwd's repository, which must then be the code repository; in a split layout every call passes `--code-repo`) and answers `status=wrong-repo expected=<sha7>` (exit 9) when the directory's root commit is not the plan line's code root; `board` alone tolerates a cwd that is no repository, since a human runs it from anywhere. The authoritative plan is the blob at the plan line's plan ref; once a plan line exists no worktree copy is read, and a plan ref that does not carry the plan file is `status=error`.
- Owner records carry `host=` for information and no pid; no subcommand judges a holder dead.
- Merge-expected files for this repository, listed here because every task touches them: `CHANGELOG.md`, `docs/testing.md`.
- Tests: every task's fixtures go into `tests/sdd/test-sdd-state.sh` unless the task names another file; the suite's runtime stays under 20 minutes; `tests/sdd/test-sdd-common.sh`, `tests/sdd/test-sdd-contract.sh`, `tests/claude-code/test-sdd-dir-path.sh`, `tests/claude-code/test-decisions-compile.sh` and `tests/shell-lint/test-lint-shell.sh` stay green. The state suite is never piped into grep: run it to a log and read the log.
- Evidence directory for the live run: `evals/evidence/2026-10-27-parallel-development/` in the hyperpowers-evals repository, named here before the first run (Task 13).
- Skill text: the Red Flags tables and rationalization lists are untouched; the SDD, writing-plans, finishing and using-git-worktrees changes are the ones the spec's Files section lists and no others; Task 14's scenario is the evidence for them.
- Commits: conventional prefix, one sentence, no attribution lines; `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` reports `hits: 0` before each commit.
- Comments explain why, in complete sentences; messages carry the `sdd-state:` prefix through `HP_PROG`; the spec is binding where this plan and the code disagree.

## Grounding

- `skills/subagent-driven-development/scripts/sdd-state:126-193`: `cmd_claim`, the atomic publish through node's `renameSync`, the lock, the `held`/`done`/`own=1`/`--takeover` contract; Tasks 3 and 5 extend it.
- `sdd-state:83-92`: `owner_record`, the `key=value` owner file; Task 3 adds fields to it.
- `sdd-state:59-79`: `resolve_plan_basic` and `resolve_plan`, the globals every subcommand uses (`PLAN_DIR`, `REPO`, `WS`, `CO`, `ROOT`, `WSDIR`).
- `sdd-state:1822-1838`: the merge plumbing in `cmd_sync` (`merge-base --is-ancestor`, `merge-tree --write-tree`, `hp_git_id ... commit-tree -p -p`); `merge-back` (Task 7) and `amend` (Task 6) mirror it.
- `sdd-state:701-764`: `cmd_finish`, the lock, `open_claims` (`:608-617`), the status grammar; Task 5 adds the session check.
- `sdd-state:1902-1946` and `verify_ledger` at `:1868-1901`: `--code-repo` handling and `wrong-repo`; Task 2 adds `wrong-branch` there and every code-ref subcommand copies the `--code-repo` resolution.
- `skills/subagent-driven-development/scripts/sdd-common.sh:258-318`: `hp_lock`, `hp_lock_at`, `hp_unlock` and `HP_LOCK_DIR`; Task 2 adds `hp_lock_pair`.
- `sdd-common.sh:345-392`: `hp_commit_paths`, a commit built in a temporary index and published by compare-and-swap `update-ref` with three attempts; `amend` mirrors its retry shape.
- `sdd-common.sh:39-43` (`hp_key`) and `:169-186` (`hp_plan_ws_name`): the key and the `<slug>-<hash8>` workspace name; `<ws8>` is that hash.
- `sdd-common.sh:114-115`: `hp_session_id`, `hp_utc_now`.
- `tests/sdd/test-sdd-state.sh:1-67`: the harness (`make_pair`, `run_state`, `state_key`, `pass`/`fail`, the temporary cache root); `:588-600` a two-process claim race; the pause barrier at the `sync-before-apply` fixture (grep `.sync-pause`); the crash seam at `HYPERPOWERS_TEST_CRASH_AT=after-worktree-add`.
- `tests/claude-code/test-decisions-compile.sh:1-40` and `:375-430`: the compiler suite's harness and its Outcome-line assertions; Task 9 extends it.
- `tests/sdd/test-sdd-contract.sh:1-30`, `:166-168`: `assert_contains` over skill text and the example-workflow session-line needles; Task 11 updates them.
- `skills/finishing-a-development-branch/scripts/decisions-compile:505-520`: `outcome_line` and `render_spec`; `:353-372` the `Recorded:` line; Task 9 changes both.
- `skills/subagent-driven-development/SKILL.md:125-262` (Setup), `:358-430` (dispatch and claims), `:695-707` (completion), `:724-804` (Final Review), `:805-847` (Finish): the sections Task 11 edits; `example-workflow.md` carries the session-line needles.
- `skills/writing-plans/SKILL.md:117-137` (the task template) and `:181-215` (No Placeholders and the self-review): Task 10 adds the `**Depends on:**` line and the Merge-expected files rule.
- `skills/finishing-a-development-branch/SKILL.md:177-240` (Step 4), `:286-345` (Step 5), `:373-420` (Step 6): Task 9 edits the merge option and adds the lease steps.
- `skills/using-git-worktrees/SKILL.md:102-112`: the worktree creation; Task 10 adds the detached start.
- `evals/scenarios/sdd-de-minimis-carveout/{story.md,setup.sh,checks.sh}` and `evals/docs/scenario-authoring.md:40-128`: the scenario anatomy Task 14 mirrors.
- none: no existing plan parser (Task 1 writes the first); none: no existing code-branch merge in the helper other than the state-branch merge cited above.
- Lock call sites at the plan's base (Task 2 Step 1 re-runs the grep and records the verdict): `sdd-state` `cmd_snapshot:108`, `cmd_claim:147`, `cmd_import:364` and `:392`, `cmd_finish:708`, `cmd_prune:827` (`--apply`) and `:981` (`hp_lock_at` on each dead checkout inside the prune walk, released inside the loop), `cmd_sync:1815`, `cmd_verify:1921`, `cmd_handoff:2005`; `sdd-dir` `refuse_ws_links:299`; `sdd-common.sh` `hp_lock:261` (the only caller of `hp_lock_at` for a repository lock) and `hp_ensure_checkout:557` and `:563`. Each subcommand takes its lock at its top with `HP_LOCK_DIR` empty; the prune walk is the one place a second `hp_lock_at` follows a first lock inside one function, and it never reaches the new subcommands.

---

### Task 1: The plan parser, `deps` and `deps --check`

**Risk tier:** high — a parser whose output `claim`, `next` and `merge-back` trust; it writes nothing, but a wrong graph is a wrong claim.

**Depends on:** none


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (new functions after `hp_plan_ws_name`, `:186`)
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (usage, `cmd_deps`, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (a new section `deps` before the `STATUS` lines)

**Interfaces:**
- Consumes: `hp_plan_rel`, `hp_plan_dir`, `resolve_plan` (`REPO`, `WS`, `WSDIR`), `ledger_path`.
- Produces: `hp_plan_graph <plan text file>` prints `task=<N> depends=<list|none>` per task in heading order, applying the serial default when no task has a `**Depends on:**` line; exits 2 with one stderr line for `mixed annotation: tasks without a Depends on line: 4, 7`, `cycle: 3 -> 5 -> 3`, `unknown task: 9 (from task 2)`, `self-dependency: task 4`, `duplicate heading: task 3`. `hp_plan_overlaps <plan text file> [<ledger file>] [<amends dir>] [<plan repo> <plan ref>]` prints `conflict tasks=<a>,<b> shares=<path>` and `conflict tasks=<a>,<b> interface=<name> direction=consumer-first` lines for undeclared overlaps, exits 0 with no output when there are none, 1 when it printed any, and honours accepted pairs from the ledger file and, when the caller passes the amendments directory and the plan repository with its ref, from the `accept=` lines of a record whose `commit=` is reachable from that ref (an unpublished record counts for nothing). Both parsers treat a fenced code block as text (a line opening with three or more backticks or tildes opens a fence; the same character, at least as many, closes it): a `### Task N:` heading, a `**Depends on:**` line or a Files block inside a fence is not a task. `plan_ref_of_ledger <ledger>` prints the plan ref from the plan line or nothing. `authoritative_plan_blob` (in `sdd-state`) prints `<blob sha> <temp file>` for the plan at the plan ref's head in `$REPO`; with a plan line, a ref that does not carry the plan file is an error (exit 2, one stderr line, no fallback); without one, the current branch's copy when it carries the file, else the file itself. `sdd-state deps PLAN_FILE [--check] [--ledger FILE] [--from FILE]` prints `status=deps plan=<blob sha7> tasks=<n>` then the graph lines (Task 2 adds `--code-repo DIR`, validated through `code_repo_arg` against the ledger's plan line); with `--check`, `status=clean plan=<sha7>` (exit 0) or `status=conflicts plan=<sha7> count=<n>` (exit 1) followed by the conflict lines; `--from FILE` parses FILE instead of the plan ref (used by `amend`); parse errors are `status=invalid` (exit 2) after the stderr line.

- [ ] **Step 1: Write the failing fixtures**

Append to `tests/sdd/test-sdd-state.sh`, before the closing `STATUS` lines (the suite's last section ends with a blank line and the `if [ "$failures" ...` block). The block opens with four backticks because the fixture itself contains three-backtick fences:

````bash
echo "deps: the plan graph and the overlap check"
make_repo "$TEST_ROOT/dp"; dp="$TEST_ROOT/dp"
mkdir -p "$dp/docs"
cat > "$dp/docs/plan.md" <<'PLAN'
# Plan

**Spec:** docs/spec.md

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`

### Task 1: A

**Risk tier:** standard

**Depends on:** none

**Files:**
- Create: `src/a.sh`
- Test: `tests/t.sh`

**Interfaces:**
- Produces: `a_fn`

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

**Files:**
- Modify: `src/b.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `a_fn`

### Task 3: C

**Risk tier:** standard

**Depends on:** none

**Files:**
- Modify: `tests/t.sh`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `a_fn`
PLAN
git -C "$dp" add docs; git -C "$dp" commit -qm plan
out=$(run_state "$dp" deps docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=deps tasks=3" ] && [ "$(printf '%s\n' "$out" | sed -n 2,4p | tr '\n' '|')" = "task=1 depends=none|task=2 depends=1|task=3 depends=none|" ]; then pass "deps prints the graph in heading order with a plan= blob"; else fail "deps prints the graph (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$dp" deps docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=conflicts count=2" ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,3 shares=tests/t.sh' && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,3 interface=a_fn direction=consumer-first' && ! printf '%s\n' "$out" | grep -q 'CHANGELOG'; then pass "deps --check names a shared Test path and a consumer without an edge, and skips a merge-expected file"; else fail "deps --check conflicts (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
printf 'scan: accepted-overlap tasks=1,3 path=tests/t.sh\nscan: accepted-overlap tasks=1,3 interface=a_fn\n' > "$TEST_ROOT/dp.ledger"
out=$(run_state "$dp" deps docs/plan.md --check --ledger "$TEST_ROOT/dp.ledger" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=clean" ]; then pass "accepted overlaps from the ledger are suppressed"; else fail "accepted overlaps suppressed (rc=$rc: $out)"; fi
# A legacy plan: no Depends on lines at all, serial by default.
sed '/^\*\*Depends on:\*\*/d' "$dp/docs/plan.md" > "$dp/docs/legacy.md"; git -C "$dp" add docs; git -C "$dp" commit -qm legacy
out=$(run_state "$dp" deps docs/legacy.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 2,4p | tr '\n' '|')" = "task=1 depends=none|task=2 depends=1|task=3 depends=1,2|" ]; then pass "a plan without Depends on lines is serial"; else fail "legacy serial default (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# Mixed annotation, a cycle, an unknown task, a self-dependency, a duplicate heading: each exit 2 with its line.
sed '0,/^\*\*Depends on:\*\* none$/{/^\*\*Depends on:\*\* none$/d;}' "$dp/docs/plan.md" > "$dp/docs/mixed.md"
err=$(run_state "$dp" deps --from docs/mixed.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'mixed annotation: tasks without a Depends on line: 1'; then pass "mixed annotation is a parse error naming the task"; else fail "mixed annotation (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* none$/**Depends on:** Task 2/' "$dp/docs/plan.md" | awk 'BEGIN{n=0} /^\*\*Depends on:\*\* Task 2$/{n++; if(n==2){print "**Depends on:** none"; next}} {print}' > "$dp/docs/cycle.md"
err=$(run_state "$dp" deps --from docs/cycle.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'cycle: '; then pass "a cycle is a parse error"; else fail "cycle (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* Task 1$/**Depends on:** Task 9/' "$dp/docs/plan.md" > "$dp/docs/unknown.md"
err=$(run_state "$dp" deps --from docs/unknown.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'unknown task: 9 (from task 2)'; then pass "an unknown dependency is a parse error"; else fail "unknown task (rc=$rc: $err)"; fi
sed 's/^\*\*Depends on:\*\* Task 1$/**Depends on:** Task 2/' "$dp/docs/plan.md" > "$dp/docs/self.md"
err=$(run_state "$dp" deps --from docs/self.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'self-dependency: task 2'; then pass "a self-dependency is a parse error"; else fail "self-dependency (rc=$rc: $err)"; fi
sed 's/^### Task 3: C$/### Task 2: C/' "$dp/docs/plan.md" > "$dp/docs/dup.md"
err=$(run_state "$dp" deps --from docs/dup.md docs/plan.md 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q 'duplicate heading: task 2'; then pass "a duplicated heading is a parse error"; else fail "duplicate heading (rc=$rc: $err)"; fi
# Fenced blocks are text: an implementation plan embeds fixture plans, and their headings are not tasks.
cp "$dp/docs/plan.md" "$dp/docs/fenced.md"
cat >> "$dp/docs/fenced.md" <<'FENCED'

### Task 4: D

**Risk tier:** standard

**Depends on:** none

**Files:**
- Create: `src/d.sh`

- [ ] **Step 1: A fixture plan inside a fence**

```bash
cat > plan.md <<'EOF'
### Task 9: Ghost

**Depends on:** Task 1

**Files:**
- Modify: `src/a.sh`
EOF
```

~~~
### Task 10: Ghost
~~~
FENCED
out=$(run_state "$dp" deps --from docs/fenced.md docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f3)" = "tasks=4" ] && ! printf '%s\n' "$out" | grep -q 'task=9\|task=10'; then pass "headings and Depends on lines inside fenced blocks are not tasks"; else fail "fenced headings (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$dp" deps --from docs/fenced.md docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f1,3)" = "status=conflicts count=2" ]; then pass "a Files block inside a fence adds no overlap"; else fail "fenced Files block (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# The authoritative plan is the plan ref's head, not the working copy.
printf '\n### Task 4: D\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n**Files:**\n- Create: `src/d.sh`\n' >> "$dp/docs/plan.md"
out=$(run_state "$dp" deps docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p | cut -d' ' -f3)" = "tasks=3" ]; then pass "deps reads the committed plan, not the working copy"; else fail "deps reads the ref (rc=$rc: $(printf '%s' "$out" | sed -n 1p))"; fi
git -C "$dp" checkout -q -- docs/plan.md
````

- [ ] **Step 2: Run the section to verify it fails**

Run: write the suite's lines 1-67 plus the new section to `~/.cache/hyperpowers/pd-deps-harness.sh` and `bash ~/.cache/hyperpowers/pd-deps-harness.sh`
Expected: every `deps` check prints `[FAIL]` (usage exit 2, `status=` empty).

- [ ] **Step 3: Write the parser in `sdd-common.sh`**

Insert after `hp_plan_ws_name` (`sdd-common.sh:186`):

```bash
# --- plan graph -------------------------------------------------------------
# <plan text file> -> one "task=N depends=<list|none>" line per "### Task N:"
# heading, in heading order. The "**Depends on:**" line under a heading
# names the tasks whose completion lines must exist before the task may be
# claimed; a plan with no such line on any task predates the dependency
# design and is read as serial (each task depends on every earlier one), so
# existing plans behave as they always did. Everything that can make the
# graph lie is a parse error here rather than a surprise at claim time.
# A fenced code block is text: an implementation plan embeds fixture plans in
# its steps, and their headings must not become tasks of the plan itself.
hp_plan_graph() {
  local f=$1 awkout rc
  awkout=$(awk '
    /^(```|~~~)/ { match($0, /^(`+|~+)/); run = substr($0, 1, RLENGTH); if (fence == "") fence = run; else if (substr(run, 1, 1) == substr(fence, 1, 1) && RLENGTH >= length(fence)) fence = ""; next }
    fence != "" { next }
    /^### Task [0-9]+:/ { n = $3; sub(/:$/, "", n); if (n in seen) { printf "duplicate heading: task %s\n", n > "/dev/stderr"; bad = 1; exit 2 } seen[n] = 1; order[++k] = n; cur = n; next }
    cur != "" && /^\*\*Depends on:\*\*/ {
      line = $0; sub(/^\*\*Depends on:\*\*[ \t]*/, "", line); gsub(/[ \t]+$/, "", line)
      if (line == "none") { dep[cur] = ""; has[cur] = 1; next }
      gsub(/Task[ \t]*/, "", line); gsub(/[ \t]/, "", line); dep[cur] = line; has[cur] = 1; next }
    END {
      if (bad) exit 2
      annotated = 0; for (i = 1; i <= k; i++) if (has[order[i]]) annotated++
      if (annotated > 0 && annotated < k) {
        printf "mixed annotation: tasks without a Depends on line:" > "/dev/stderr"; sep = " "
        for (i = 1; i <= k; i++) if (!has[order[i]]) { printf "%s%s", sep, order[i] > "/dev/stderr"; sep = ", " }
        printf "\n" > "/dev/stderr"; exit 2 }
      if (annotated == 0) { for (i = 1; i <= k; i++) { d = ""; for (j = 1; j < i; j++) d = d (d == "" ? "" : ",") order[j]; dep[order[i]] = d } }
      for (i = 1; i <= k; i++) { t = order[i]; m = split(dep[t], parts, ",")
        for (p = 1; p <= m; p++) { if (parts[p] == "") continue
          if (!(parts[p] in seen)) { printf "unknown task: %s (from task %s)\n", parts[p], t > "/dev/stderr"; exit 2 }
          if (parts[p] == t) { printf "self-dependency: task %s\n", t > "/dev/stderr"; exit 2 } } }
      # Kahn: a cycle is whatever never reaches in-degree zero.
      for (i = 1; i <= k; i++) { t = order[i]; m = split(dep[t], parts, ","); indeg[t] = 0; for (p = 1; p <= m; p++) if (parts[p] != "") { indeg[t]++; succ[parts[p]] = succ[parts[p]] " " t } }
      done = 0; changed = 1
      while (changed) { changed = 0; for (i = 1; i <= k; i++) { t = order[i]; if (!(t in out) && indeg[t] == 0) { out[t] = 1; done++; changed = 1; m = split(succ[t], s, " "); for (p = 1; p <= m; p++) if (s[p] != "") indeg[s[p]]-- } } }
      if (done < k) { first = ""; for (i = 1; i <= k; i++) if (!(order[i] in out)) { first = order[i]; break }
        path = first; t = first; for (g = 0; g < k; g++) { m = split(dep[t], parts, ","); nxt = ""; for (p = 1; p <= m; p++) if (parts[p] != "" && !(parts[p] in out)) { nxt = parts[p]; break } if (nxt == "") break; path = path " -> " nxt; if (nxt == first) break; t = nxt }
        printf "cycle: %s\n", path > "/dev/stderr"; exit 2 }
      for (i = 1; i <= k; i++) printf "task=%s depends=%s\n", order[i], (dep[order[i]] == "" ? "none" : dep[order[i]])
    }' "$f" 2>&1 >/dev/null; true)
  # The awk above sends diagnostics to stderr and data to stdout; run it once
  # more for the data when it succeeded, so the two streams never interleave.
  if [ -n "$awkout" ]; then printf '%s\n' "$awkout" >&2; return 2; fi
  awk '/^(```|~~~)/ { match($0, /^(`+|~+)/); run = substr($0, 1, RLENGTH); if (fence == "") fence = run; else if (substr(run, 1, 1) == substr(fence, 1, 1) && RLENGTH >= length(fence)) fence = ""; next }
       fence != "" { next }
       /^### Task [0-9]+:/ { n = $3; sub(/:$/, "", n); order[++k] = n; cur = n; next }
       cur != "" && /^\*\*Depends on:\*\*/ { line = $0; sub(/^\*\*Depends on:\*\*[ \t]*/, "", line); gsub(/[ \t]+$/, "", line); if (line == "none") { dep[cur] = ""; has[cur] = 1; next } gsub(/Task[ \t]*/, "", line); gsub(/[ \t]/, "", line); dep[cur] = line; has[cur] = 1; next }
       END { annotated = 0; for (i = 1; i <= k; i++) if (has[order[i]]) annotated++
             if (annotated == 0) { for (i = 1; i <= k; i++) { d = ""; for (j = 1; j < i; j++) d = d (d == "" ? "" : ",") order[j]; dep[order[i]] = d } }
             for (i = 1; i <= k; i++) printf "task=%s depends=%s\n", order[i], (dep[order[i]] == "" ? "none" : dep[order[i]]) }' "$f"
}

# <plan text file> [<ledger file>] [<amends dir>] -> one "conflict ..." line
# per pair of tasks that share a Create, Modify or Test path, or an interface
# (a backticked name in one task's Produces and another's Consumes), without
# one depending on the other directly or through a chain; a consumer must
# follow its producer, so the reverse edge does not clear an interface pair.
# Paths under "**Merge-expected files:**" in Global Constraints never conflict.
# Accepted pairs are read from "scan: accepted-overlap" ledger lines and from
# "accept=" lines in amendment records whose commit is on the plan ref (a
# record a failed attempt left behind must not hide a conflict). Exit 1 when
# any line was printed.
hp_plan_overlaps() { # <plan text> [<ledger>] [<amends dir>] [<plan repo> <plan ref>]
  local f=$1 ledger=${2:-} amends=${3:-} graph accepted rec c
  graph=$(hp_plan_graph "$f") || return 2
  accepted=""
  [ -n "$ledger" ] && [ -f "$ledger" ] && accepted=$(sed -n 's/^scan: accepted-overlap //p' "$ledger")
  if [ -n "$amends" ] && [ -d "$amends" ] && [ -n "${4:-}" ] && [ -n "${5:-}" ]; then
    for rec in "$amends"/*; do
      [ -f "$rec" ] || continue
      c=$(sed -n 's/^commit=//p' "$rec"); [ -n "$c" ] || continue
      git -C "$4" merge-base --is-ancestor "$c" "refs/heads/$5" 2>/dev/null || continue
      accepted="$accepted
$(sed -n 's/^accept=//p' "$rec")"
    done
  fi
  awk -v graph="$graph" -v accepted="$accepted" '
    BEGIN {
      m = split(graph, g, "\n"); for (i = 1; i <= m; i++) { if (g[i] == "") continue; split(g[i], kv, " "); t = substr(kv[1], 6); d = substr(kv[2], 9); order[++k] = t; if (d != "none") { c = split(d, parts, ","); for (p = 1; p <= c; p++) direct[t, parts[p]] = 1 } }
      # transitive closure: after[a,b] means a depends on b through a chain
      for (i = 1; i <= k; i++) for (j = 1; j <= k; j++) if (direct[order[i], order[j]]) after[order[i], order[j]] = 1
      for (x = 1; x <= k; x++) for (i = 1; i <= k; i++) for (j = 1; j <= k; j++) if (after[order[i], order[x]] && after[order[x], order[j]]) after[order[i], order[j]] = 1
      n = split(accepted, acc, "\n"); for (i = 1; i <= n; i++) if (acc[i] != "") ok[acc[i]] = 1
    }
    /^(```|~~~)/ { match($0, /^(`+|~+)/); run = substr($0, 1, RLENGTH); if (fence == "") fence = run; else if (substr(run, 1, 1) == substr(fence, 1, 1) && RLENGTH >= length(fence)) fence = ""; next }
    fence != "" { next }
    /^## Global Constraints/ { gc = 1; next }
    /^## / { gc = 0 }
    gc && /Merge-expected files:/ { s = $0; while (match(s, /`[^`]+`/)) { me[substr(s, RSTART + 1, RLENGTH - 2)] = 1; s = substr(s, RSTART + RLENGTH) } }
    /^### Task [0-9]+:/ { cur = $3; sub(/:$/, "", cur); mode = ""; next }
    cur == "" { next }
    /^\*\*Files:\*\*/ { mode = "files"; next }
    /^\*\*Interfaces:\*\*/ { mode = "ifaces"; next }
    /^\*\*/ && !/^\*\*Files:\*\*/ && !/^\*\*Interfaces:\*\*/ { mode = "" }
    mode == "files" && /^- (Create|Modify|Test):/ { s = $0; while (match(s, /`[^`]+`/)) { p = substr(s, RSTART + 1, RLENGTH - 2); sub(/:[0-9-]+$/, "", p); if (!(p in me)) paths[cur, p] = 1; s = substr(s, RSTART + RLENGTH) } next }
    mode == "ifaces" && /^- Produces:/ { s = $0; while (match(s, /`[^`]+`/)) { prod[cur, substr(s, RSTART + 1, RLENGTH - 2)] = 1; s = substr(s, RSTART + RLENGTH) } next }
    mode == "ifaces" && /^- Consumes:/ { s = $0; while (match(s, /`[^`]+`/)) { cons[cur, substr(s, RSTART + 1, RLENGTH - 2)] = 1; s = substr(s, RSTART + RLENGTH) } next }
    END {
      any = 0
      for (i = 1; i <= k; i++) for (j = i + 1; j <= k; j++) { a = order[i]; b = order[j]
        if (after[a, b] || after[b, a]) continue
        for (key in paths) { split(key, kp, SUBSEP); if (kp[1] != a) continue; if ((b, kp[2]) in paths) { line = "tasks=" a "," b " path=" kp[2]; if (!(line in ok)) { printf "conflict tasks=%s,%s shares=%s\n", a, b, kp[2]; any = 1 } } } }
      for (key in prod) { split(key, kp, SUBSEP); pr = kp[1]; name = kp[2]
        for (co = 1; co <= k; co++) { c = order[co]; if (c == pr || !((c, name) in cons)) continue
          if (after[c, pr]) continue
          lo = (pr + 0 < c + 0) ? pr : c; hi = (pr + 0 < c + 0) ? c : pr
          line = "tasks=" lo "," hi " interface=" name; if (!(line in ok)) { printf "conflict tasks=%s,%s interface=%s direction=consumer-first\n", lo, hi, name; any = 1 } } }
      exit any
    }' "$f"
}

# <ledger> -> the plan ref recorded by the plan line, or nothing.
plan_ref_of_ledger() { sed -n 's/^plan: integration .* plan-ref \([^ ]*\) .*/\1/p' "$1" 2>/dev/null | tail -n 1; }
```

- [ ] **Step 4: Write `cmd_deps` and the authoritative-plan reader in `sdd-state`**

Add to the usage block (both the header comment and `usage()`):

```
  deps PLAN_FILE [--check] [--ledger FILE] [--from FILE]
```

Insert before `# --- snapshot` (`sdd-state:93`):

```bash
# --- deps --------------------------------------------------------------------
# The authoritative plan is the blob at the plan ref's head in the plan
# repository, never a worktree's copy: two sessions on two task branches
# would otherwise read two graphs. With a plan line the ref is the line's
# and must carry the file (an error otherwise, never a fallback); before
# registration it is the current branch when that carries the file, and the
# file itself only then.
# Prints "<blob sha> <path of a temporary copy>"; the caller removes the copy.
authoritative_plan_blob() {
  local ledger ref rel blob tmp cur
  ledger=$(ledger_path); rel=$(hp_plan_rel "$PLAN")
  ref=$(plan_ref_of_ledger "$ledger")
  tmp=$(mktemp "${TMPDIR:-/tmp}/sdd-plan.XXXXXX") || return 2
  if [ -n "$ref" ]; then
    git -C "$REPO" cat-file -e "refs/heads/$ref:$rel" 2>/dev/null || { rm -f "$tmp"; echo "sdd-state: the plan ref $ref does not carry $rel" >&2; return 2; }
    git -C "$REPO" show "refs/heads/$ref:$rel" > "$tmp" || { rm -f "$tmp"; return 2; }
    blob=$(git -C "$REPO" rev-parse "refs/heads/$ref:$rel")
  elif cur=$(git -C "$REPO" branch --show-current 2>/dev/null) && [ -n "$cur" ] && git -C "$REPO" cat-file -e "refs/heads/$cur:$rel" 2>/dev/null; then
    git -C "$REPO" show "refs/heads/$cur:$rel" > "$tmp" || { rm -f "$tmp"; return 2; }
    blob=$(git -C "$REPO" rev-parse "refs/heads/$cur:$rel")
  else
    cp "$PLAN" "$tmp" || { rm -f "$tmp"; return 2; }
    blob=$(git -C "$REPO" hash-object "$tmp")
  fi
  printf '%s %s\n' "$blob" "$tmp"
}
cmd_deps() {
  local plan="" check=0 ledger="" from="" pair blob tmp graph rc out n ref
  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check=1; shift ;;
      --ledger) [ $# -ge 2 ] || usage; ledger=$2; shift 2 ;;
      --from) [ $# -ge 2 ] || usage; from=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  [ -n "$ledger" ] || ledger=$(ledger_path)
  ref=$(plan_ref_of_ledger "$ledger"); [ -n "$ref" ] || ref=$(git -C "$REPO" branch --show-current 2>/dev/null)
  if [ -n "$from" ]; then
    [ -f "$from" ] || { echo "sdd-state: no such file: $from" >&2; echo "status=error"; return 2; }
    tmp=$from; blob=$(git -C "$REPO" hash-object "$from")
  else
    pair=$(authoritative_plan_blob) || { echo "status=error"; return 2; }
    blob=${pair%% *}; tmp=${pair#* }
  fi
  if ! graph=$(hp_plan_graph "$tmp"); then [ -n "$from" ] || rm -f "$tmp"; echo "status=invalid plan=${blob:0:7}"; return 2; fi
  if [ "$check" -eq 0 ]; then
    [ -n "$from" ] || rm -f "$tmp"
    n=$(printf '%s\n' "$graph" | grep -c .)
    echo "status=deps plan=${blob:0:7} tasks=$n"; printf '%s\n' "$graph"; return 0
  fi
  out=$(hp_plan_overlaps "$tmp" "$ledger" "$(dirname "$ledger")/amends" "$REPO" "$ref"); rc=$?
  [ -n "$from" ] || rm -f "$tmp"
  [ "$rc" -ne 2 ] || { echo "status=error"; return 2; }
  if [ "$rc" -eq 0 ]; then echo "status=clean plan=${blob:0:7}"; return 0; fi
  n=$(printf '%s\n' "$out" | grep -c .)
  echo "status=conflicts plan=${blob:0:7} count=$n"; printf '%s\n' "$out"; return 1
}
```

Add `deps) cmd_deps "$@" ;;` to the dispatch `case`.

- [ ] **Step 5: Run the section to verify it passes, and parse this plan with it**

Run: `bash ~/.cache/hyperpowers/pd-deps-harness.sh`
Expected: every `deps` check prints `[PASS]`.

Run, from the worktree root: `bash skills/subagent-driven-development/scripts/sdd-state deps --from docs/hyperpowers/plans/2026-10-27-parallel-development.md docs/hyperpowers/plans/2026-10-27-parallel-development.md`
Expected: `status=deps plan=<sha7> tasks=14`, then `task=1 depends=none`, `task=2 depends=1`, ..., `task=13 depends=12`, `task=14 depends=13`: this plan's fixture plans sit inside fences and are not its tasks. Append the first line to the ledger as `plan parses itself: <line>`.

- [ ] **Step 6: Lint and commit**

Run: `bash tests/shell-lint/test-lint-shell.sh` (expected: passes) and `git diff --cached | python3 ~/.claude/scripts/realval-scan.py` after staging (expected: `hits: 0`).

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): deps parses a plan's dependency graph from the plan ref and checks declared independence against overlap"
```

### Task 2: `register`, the plan line, `verify`'s `wrong-branch` and the lock pair

**Risk tier:** high — a durable ledger write under two locks, and the lock-order helper every later subcommand uses.

**Depends on:** Task 1


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (`hp_lock_pair`, `hp_unlock` for two locks, `hp_lease_key`, after `hp_unlock` at `:318`)
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`code_repo_arg`, `cmd_register`, `verify`'s branch check, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `register`)

**Interfaces:**
- Consumes: `hp_lock_at`, `hp_key`, `hp_checkout_path`, `root_of` (`sdd-state:1860`), `hp_plan_rel`, `ledger_path`.
- Produces: `hp_lock_pair <repoA> <repoB>` takes both repositories' locks in ascending `hp_key` order (one lock when the keys are equal) and sets `HP_LOCK_DIR` and `HP_LOCK_DIR2`; `hp_unlock` releases both. `hp_lease_key <repo-dir> <branch>` prints `<checkout path>.final-<ref12>`. `code_repo_arg <value> [<ledger>]` resolves `--code-repo` (empty means the cwd's toplevel) to a physical path or exits 2 with the `verify` message, and, when a ledger with a plan line is given, prints `status=wrong-repo expected=<code-root sha7>` and exits 9 when the directory's root commit is not the recorded one; every subcommand that takes `--code-repo` (`deps`, `register`, `claim`, `next`, `lease`, `amend`, `merge-back`, `board`, `finish`) passes the ledger with one idiom, `code=$(code_repo_arg "$code" "$ledger") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }` (the status line travels on stdout, the exit code in `$?`; a usage failure printed nothing). `plan_line_of <ledger>` prints the plan line's fields as `integration=<b> code-root=<sha7> plan-ref=<r> plan-root=<sha7> spec=<p>` or nothing. `sdd-state register PLAN_FILE --session SID --integration BRANCH [--code-repo DIR]` answers `status=registered integration=<b> plan-ref=<r>` (exit 0); for a plan already registered, `status=wrong-branch expected=<b>` or `status=wrong-branch expected=<r> repo=plan` and `status=wrong-repo expected=<sha7>[ repo=plan]` (exit 9) when any of the five recorded fields differs, and `status=error` naming the field for a different spec; `status=spec-branch-mismatch expected=<b> plan=<ws>` (exit 9); `status=branch-closing` (exit 15, the first check under the locks); `status=detached-head repo=plan` (exit 11) for a first registration only, since the plan ref is named after the current branch; a re-registration takes the plan ref from the plan line, so a later session registers from a detached checkout or from one of this plan's task branches, and only a named branch that is neither is `wrong-branch ... repo=plan`. `register` holds `hp_lock_pair`. `cmd_deps` gains `--code-repo DIR` here, validated the same way. `verify` additionally answers `status=wrong-branch expected=<b>` (exit 9) when the code repository's current branch is a named branch that is neither the integration branch nor one of this plan's task branches (`<b>.<ws8>.task-*`). The spec path is the plan header's `**Spec:**` value as written.

**Mirror:** `sdd-state:1902-1920`, the `--code-repo` resolution in `cmd_verify`; `sdd-common.sh:265-303`, `hp_lock_at`.

- [ ] **Step 1: Audit every lock call site**

The lock pair below is safe only if no caller reaches it while already holding a lock. Run:

```bash
grep -n -E 'hp_lock(_at)?( |$|")' skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state skills/subagent-driven-development/scripts/sdd-dir | grep -v ':[0-9]*:[[:space:]]*#'
```

For each site, read the enclosing function and append one ledger line `lock audit: <file>:<line> <function> entered-holding=<none|lock> reaches-pair=<no|yes>`, then the verdict line, `lock audit: verdict no caller holds a lock when it would enter hp_lock_pair` or `lock audit: verdict callers: <list>`. The Grounding section lists the sites at the plan's base; the one function that takes a second lock after a first is `cmd_prune`, whose dead-checkout walk takes and releases each checkout's lock inside its loop and never reaches a new subcommand. A verdict naming callers is a plan conflict for your human partner, not a value to guess: Step 4 does not start until the verdict is the no-nesting one.

- [ ] **Step 2: Write the failing fixtures**

```bash
echo "register: the plan line, siblings and the lock pair"
make_pair rg; rg_a=$PAIR_A
mkdir -p "$rg_a/docs"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan.md"; : > "$rg_a/docs/spec.md"
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan2.md"
git -C "$rg_a" add docs; git -C "$rg_a" commit -qm plans; git -C "$rg_a" push -q origin main 2>/dev/null
git -C "$rg_a" switch -q -c feat
run_state "$rg_a" sync docs/plan.md >/dev/null 2>&1; wsr=$(run_sdd_dir "$rg_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsr/progress.md"
out=$(run_state "$rg_a" register docs/plan.md --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ] && grep -q "^plan: integration feat code-root [0-9a-f]\{7\} plan-ref feat plan-root [0-9a-f]\{7\} spec docs/spec.md$" "$wsr/progress.md"; then pass "register writes the plan line once"; else fail "register writes the plan line (rc=$rc: $out: $(grep '^plan:' "$wsr/progress.md" 2>/dev/null))"; fi
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ] && [ "$(grep -c '^plan: integration' "$wsr/progress.md")" = 1 ]; then pass "a matching re-registration is a no-op"; else fail "matching re-registration (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration other 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ]; then pass "a different branch for a registered plan is wrong-branch"; else fail "wrong-branch (rc=$rc: $out)"; fi
wsr2=$(run_sdd_dir "$rg_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsr2/progress.md"
out=$(run_state "$rg_a" register docs/plan2.md --session s3 --integration feat2 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% plan=*}" = "status=spec-branch-mismatch expected=feat" ] && [ "${out##* plan=}" = "$(basename "$wsr")" ]; then pass "a sibling plan of the same spec must share the integration branch"; else fail "spec-branch-mismatch (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" register docs/plan2.md --session s3 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "a sibling on the same branch registers"; else fail "sibling registers (rc=$rc: $out)"; fi
# verify: a named branch that is neither the integration branch nor a task branch.
git -C "$rg_a" switch -q -c stray
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat" ]; then pass "verify reports wrong-branch on a stray branch"; else fail "verify wrong-branch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q -c "feat.$(basename "$wsr" | sed 's/.*-//').task-1" feat
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=ok" ]; then pass "verify accepts this plan's task branch"; else fail "verify task branch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q --detach feat
out=$(run_state "$rg_a" verify docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "verify accepts a detached checkout"; else fail "verify detached (rc=$rc: $out)"; fi
# A later session registers detached (the plan ref comes from the plan line) or from this plan's task branch; a first registration needs a named branch.
out=$(run_state "$rg_a" register docs/plan.md --session s9 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=feat" ]; then pass "a later session registers from a detached checkout"; else fail "detached re-registration (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q "feat.$(basename "$wsr" | sed 's/.*-//').task-1"
out=$(run_state "$rg_a" register docs/plan.md --session s9 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "a session on this plan's task branch re-registers"; else fail "task-branch re-registration (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q --detach feat
printf '# T\n\n**Spec:** docs/spec3.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$rg_a/docs/plan3.md"; : > "$rg_a/docs/spec3.md"
wsr3=$(run_sdd_dir "$rg_a" docs/plan3.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan3.md\n' > "$wsr3/progress.md"
out=$(run_state "$rg_a" register docs/plan3.md --session s9 --integration feat3 2>/dev/null); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=detached-head repo=plan" ] && ! grep -q '^plan:' "$wsr3/progress.md"; then pass "a first registration needs a named branch to name the plan ref"; else fail "detached first registration (rc=$rc: $out)"; fi
rm -rf "$wsr3"; rm -f "$rg_a/docs/plan3.md" "$rg_a/docs/spec3.md"
git -C "$rg_a" switch -q feat
make_repo "$TEST_ROOT/foreign"
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat --code-repo "$TEST_ROOT/foreign" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "register refuses a code repository whose root is not the recorded code root"; else fail "register wrong-repo (rc=$rc: $out)"; fi
out=$(run_state "$rg_a" deps docs/plan.md --code-repo "$TEST_ROOT/foreign" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "deps refuses a foreign --code-repo once the plan line exists"; else fail "deps wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign" && bash "$SDD_STATE" deps "$rg_a/docs/plan.md" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "deps run from a foreign repository without --code-repo is wrong-repo"; else fail "deps foreign cwd (rc=$rc: $out)"; fi
# A re-registration must match the whole plan line: the plan ref and the plan root too.
git -C "$rg_a" switch -q -c feat-b feat
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-branch expected=feat repo=plan" ]; then pass "a plan repository on another branch than the recorded plan ref is wrong-branch repo=plan"; else fail "plan-ref mismatch (rc=$rc: $out)"; fi
git -C "$rg_a" switch -q feat
pl_orig=$(grep '^plan: integration' "$wsr/progress.md")
sed -i '' 's| plan-root [0-9a-f]* spec | plan-root 0000000 spec |' "$wsr/progress.md" 2>/dev/null || sed -i 's| plan-root [0-9a-f]* spec | plan-root 0000000 spec |' "$wsr/progress.md"
out=$(run_state "$rg_a" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "$out" = "status=wrong-repo expected=0000000 repo=plan" ]; then pass "a recorded plan root that is not this repository's is wrong-repo repo=plan"; else fail "plan-root mismatch (rc=$rc: $out)"; fi
sed -i '' "s|^plan: integration .*|$pl_orig|" "$wsr/progress.md" 2>/dev/null || sed -i "s|^plan: integration .*|$pl_orig|" "$wsr/progress.md"
# The plan in one repository and the code in another: the state lives with the plan, the plan line records both roots.
make_repo "$TEST_ROOT/sp"; make_repo "$TEST_ROOT/sc"; sp="$TEST_ROOT/sp"; sc="$TEST_ROOT/sc"
mkdir -p "$sp/docs"; printf '# S\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$sp/docs/plan.md"; : > "$sp/docs/spec.md"; git -C "$sp" add docs; git -C "$sp" commit -qm plan; git -C "$sp" switch -q -c plans
git -C "$sc" switch -q -c feat
wssp=$(run_sdd_dir "$sp" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wssp/progress.md"
root_sc=$(git -C "$sc" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7); root_sp=$(git -C "$sp" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7)
out=$(cd "$sc" && bash "$SDD_STATE" register "$sp/docs/plan.md" --session s1 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=plans" ] && grep -q "^plan: integration feat code-root $root_sc plan-ref plans plan-root $root_sp spec docs/spec.md$" "$wssp/progress.md"; then pass "a split layout records the code root from the cwd and the plan ref from the plan repository"; else fail "split register (rc=$rc: $out: $(grep '^plan:' "$wssp/progress.md" 2>/dev/null))"; fi
out=$(run_state "$sp" register docs/plan.md --session s2 --integration feat --code-repo "$sc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=registered integration=feat plan-ref=plans" ]; then pass "a re-registration from the plan repository with --code-repo matches"; else fail "split re-register (rc=$rc: $out)"; fi
out=$(run_state "$sp" register docs/plan.md --session s2 --integration feat 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "the plan repository itself is not the code repository"; else fail "split wrong-repo (rc=$rc: $out)"; fi
# Two sibling registrations with different branches through a barrier: exactly one succeeds.
git -C "$rg_a" switch -q feat
rm -rf "$wsr2"; wsr2=$(run_sdd_dir "$rg_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsr2/progress.md"
sed -i '' '/^plan: integration/d' "$wsr/progress.md" 2>/dev/null || sed -i '/^plan: integration/d' "$wsr/progress.md"
co_r=$(dirname "$(dirname "$wsr")")
: > "$co_r/.register-before-write-pause"
( cd "$rg_a" && HYPERPOWERS_TEST_PAUSE_AT=register-before-write bash "$SDD_STATE" register docs/plan.md --session s1 --integration feat > "$TEST_ROOT/rg.1" 2>/dev/null; echo $? > "$TEST_ROOT/rg.1rc" ) &
n=0; while [ ! -e "$co_r/.register-before-write-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
( cd "$rg_a" && bash "$SDD_STATE" register docs/plan2.md --session s3 --integration feat2 > "$TEST_ROOT/rg.2" 2>/dev/null; echo $? > "$TEST_ROOT/rg.2rc" ) &
sleep 0.5; rm -f "$co_r/.register-before-write-pause"; wait
r1=$(cat "$TEST_ROOT/rg.1rc"); r2=$(cat "$TEST_ROOT/rg.2rc")
if { [ "$r1" = 0 ] && [ "$r2" = 9 ]; } || { [ "$r1" = 9 ] && [ "$r2" = 0 ]; }; then pass "two sibling registrations with different branches: exactly one succeeds"; else fail "registration race (rcs $r1 $r2: $(cat "$TEST_ROOT/rg.1") / $(cat "$TEST_ROOT/rg.2"))"; fi
# The lock pair in ascending key order, roles swapped between two operations.
make_repo "$TEST_ROOT/lk1"; make_repo "$TEST_ROOT/lk2"
( . "$LIB"; HYPERPOWERS_TEST_PAUSE_AT=lock-pair-between hp_lock_pair "$TEST_ROOT/lk1" "$TEST_ROOT/lk2" > /dev/null 2>&1; echo "$HP_LOCK_DIR" > "$TEST_ROOT/lk.first"; hp_unlock ) &
sleep 0.3
( . "$LIB"; hp_lock_pair "$TEST_ROOT/lk2" "$TEST_ROOT/lk1" > /dev/null 2>&1; echo "$HP_LOCK_DIR" > "$TEST_ROOT/lk.second"; hp_unlock ) &
sleep 0.3; rm -f "$XDG_CACHE_HOME"/hyperpowers/state/*.lock-pair-between-pause 2>/dev/null; wait
k1=$(state_key "$TEST_ROOT/lk1"); k2=$(state_key "$TEST_ROOT/lk2"); lower=$k1; [ "$k1" \< "$k2" ] || lower=$k2
if [ "$(basename "$(cat "$TEST_ROOT/lk.first")" .lock)" = "$lower" ] && [ "$(basename "$(cat "$TEST_ROOT/lk.second")" .lock)" = "$lower" ]; then pass "hp_lock_pair takes the lower key first whichever role each repository plays"; else fail "lock pair order ($(cat "$TEST_ROOT/lk.first") / $(cat "$TEST_ROOT/lk.second") lower=$lower)"; fi
```

- [ ] **Step 3: Run the section to verify it fails**

Run the extracted harness as in Task 1 (`~/.cache/hyperpowers/pd-register-harness.sh`).
Expected: every `register` check prints `[FAIL]`.

- [ ] **Step 4: The lock pair and the lease key in `sdd-common.sh`**

Insert after `hp_unlock` (`sdd-common.sh:308`), replacing `hp_unlock`'s body so it releases both locks:

```bash
# Two repositories' locks are taken in ascending key order whichever role
# each plays (plan or code), so two sessions whose roles are swapped cannot
# wait on each other. Equal keys mean one repository: one lock.
: "${HP_LOCK_DIR2:=}"
hp_lock_pair() { # <repoA> <repoB>
  local ka kb first second la lb
  ka=$(hp_key "$1") || return 2; kb=$(hp_key "$2") || return 2
  if [ "$ka" = "$kb" ]; then hp_lock "$1"; return $?; fi
  if [ "$ka" \< "$kb" ]; then first=$1; second=$2; else first=$2; second=$1; fi
  la=$(hp_checkout_path "$first") || return 2; lb=$(hp_checkout_path "$second") || return 2
  hp_lock_at "$la.lock" || return 2
  if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = lock-pair-between ]; then
    : > "$la.lock-pair-between-paused"
    while [ -e "$la.lock-pair-between-pause" ]; do sleep 0.1; done
    rm -f "$la.lock-pair-between-paused"
  fi
  HP_LOCK_DIR2=$HP_LOCK_DIR; HP_LOCK_DIR=""
  if ! hp_lock_at "$lb.lock"; then HP_LOCK_DIR=$HP_LOCK_DIR2; HP_LOCK_DIR2=""; hp_unlock; return 2; fi
  # hp_lock_at left HP_LOCK_DIR on the second lock; the first is held in
  # HP_LOCK_DIR2 so that one hp_unlock, the trap included, releases both,
  # the first-taken lock last.
}
hp_unlock() {
  local d
  for d in "$HP_LOCK_DIR" "$HP_LOCK_DIR2"; do
    if [ -n "$d" ] && [ "$(sed -n 's/^pid=//p' "$d/owner" 2>/dev/null)" = "$$" ]; then rm -rf "$d"; fi
  done
  HP_LOCK_DIR=""; HP_LOCK_DIR2=""
}
# <repo-dir> <branch> -> the lease file for the branch beside the lock: a
# branch name may hold slashes, so the file is keyed by a digest of the full
# ref name and carries the name inside.
hp_lease_key() {
  local c ref12
  c=$(hp_checkout_path "$1") || return 1
  ref12=$(printf 'refs/heads/%s' "$2" | git -C "$1" hash-object --stdin | cut -c1-12)
  printf '%s.final-%s\n' "$c" "$ref12"
}
```

(Remove the earlier `hp_unlock` definition at `:304-308`; the lint flags a duplicate function.)

- [ ] **Step 5: `register`, the plan line reader, `code_repo_arg` and `verify`'s branch check in `sdd-state`**

Usage lines:

```
  register PLAN_FILE --session SID --integration BRANCH [--code-repo DIR]
  verify PLAN_FILE [--code-repo DIR]
```

Insert after `enc()` (`sdd-state:82`):

```bash
# --code-repo DIR, or the cwd's toplevel: the repository that owns the
# integration branch when the plan lives elsewhere. Exits 2 as verify does.
code_repo_arg() { # <value or empty> [<ledger>] -> physical path; refuses a repository whose root is not the recorded code root
  local code=$1 ledger=${2:-} line want
  if [ -z "$code" ]; then
    code=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "sdd-state: not inside a code repository; pass --code-repo DIR" >&2; exit 2; }
  fi
  code=$(hp_physical_dir "$code") || { echo "sdd-state: no such directory: $code" >&2; exit 2; }
  if [ -n "$ledger" ] && [ -f "$ledger" ]; then
    line=$(plan_line_of "$ledger")
    if [ -n "$line" ]; then
      want=$(plan_field "$line" code-root)
      if [ "$(root_of "$code" | cut -c1-7)" != "$want" ]; then echo "status=wrong-repo expected=$want"; exit 9; fi
    fi
  fi
  printf '%s\n' "$code"
}
# <ledger> -> "integration=.. code-root=.. plan-ref=.. plan-root=.. spec=.." from the newest plan line, or nothing.
plan_line_of() {
  sed -n 's/^plan: integration \([^ ]*\) code-root \([^ ]*\) plan-ref \([^ ]*\) plan-root \([^ ]*\) spec \(.*\)$/integration=\1 code-root=\2 plan-ref=\3 plan-root=\4 spec=\5/p' "$1" 2>/dev/null | tail -n 1
}
plan_field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -n 1; }
spec_of_plan() { sed -n 's/^\*\*Spec:\*\*[[:space:]]*//p' "$1" | head -n 1; }
ws8_of() { printf '%s' "$1" | sed 's/.*-//'; }
```

Insert before `# --- snapshot`:

```bash
# --- register ----------------------------------------------------------------
# A session's first act on a plan. The check (siblings of the same spec share
# the integration branch, the plan ref and the plan root; the branch is not
# closing; an existing line matches) and the write happen under both
# repositories' locks, so two Setups cannot both pass and write conflicting
# lines.
cmd_register() {
  local plan="" sid="" integration="" code="" ledger line spec plan_ref plan_root code_root d other ospec field lease rc mine cur
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --integration) [ $# -ge 2 ] || usage; integration=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$sid" ] && [ -n "$integration" ] || usage
  resolve_plan "$plan"
  ledger=$(ledger_path)
  [ -f "$ledger" ] || { echo "sdd-state: no ledger at $ledger; Setup creates it before registering" >&2; echo "status=error"; return 2; }
  code=$(code_repo_arg "$code" "$ledger") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  spec=$(spec_of_plan "$PLAN")
  # A first registration names the plan ref after the current branch, so the
  # plan repository must be on one then; a later session starts detached at
  # the integration head and takes the plan ref from the plan line instead.
  cur=$(git -C "$REPO" branch --show-current 2>/dev/null)
  plan_root=$(root_of "$REPO"); code_root=$(root_of "$code")
  hp_lock_pair "$PLAN_DIR" "$code" || return 2
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = register-before-write ]; then
    : > "$CO/.register-before-write-paused"
    while [ -e "$CO/.register-before-write-pause" ]; do sleep 0.1; done
    rm -f "$CO/.register-before-write-paused"
  fi
  # The closing check comes first: a branch being torn down admits nothing,
  # not even a session of a plan already registered on it.
  lease=$(hp_lease_key "$PLAN_DIR" "$integration")
  if [ -f "$lease" ] && [ "$(sed -n 's/^closing=//p' "$lease")" = 1 ]; then hp_unlock; echo "status=branch-closing"; return 15; fi
  line=$(plan_line_of "$ledger")
  if [ -n "$line" ]; then
    # A re-registration must match the whole recorded identity: a session
    # arriving from another checkout of the plan repository, or with another
    # spec header, is not this plan's session.
    hp_unlock
    plan_ref=$(plan_field "$line" plan-ref)
    [ "$(plan_field "$line" integration)" = "$integration" ] || { echo "status=wrong-branch expected=$(plan_field "$line" integration)"; return 9; }
    [ "$(plan_field "$line" code-root)" = "${code_root:0:7}" ] || { echo "status=wrong-repo expected=$(plan_field "$line" code-root)"; return 9; }
    # Detached, on the plan ref, or on one of this plan's task branches: a
    # resumed session sits on any of the three.
    case "$cur" in ""|"$plan_ref"|"$integration.$(ws8_of "$WS").task-"*) ;; *) echo "status=wrong-branch expected=$plan_ref repo=plan"; return 9 ;; esac
    [ "$(plan_field "$line" plan-root)" = "${plan_root:0:7}" ] || { echo "status=wrong-repo expected=$(plan_field "$line" plan-root) repo=plan"; return 9; }
    [ "$(plan_field "$line" spec)" = "$spec" ] || { echo "sdd-state: the plan line names spec $(plan_field "$line" spec), the plan file names $spec" >&2; echo "status=error"; return 2; }
    echo "status=registered integration=$integration plan-ref=$plan_ref"; return 0
  fi
  [ -n "$cur" ] || { hp_unlock; echo "status=detached-head repo=plan"; return 11; }
  plan_ref=$cur
  for d in "$ROOT"/plans/*/; do
    [ -f "$d/progress.md" ] || continue
    [ "${d%/}" != "$WSDIR" ] || continue
    other=$(plan_line_of "$d/progress.md"); [ -n "$other" ] || continue
    ospec=$(plan_field "$other" spec); [ "$ospec" = "$spec" ] || continue
    for field in integration plan-ref plan-root; do
      case "$field" in integration) mine=$integration ;; plan-ref) mine=$plan_ref ;; plan-root) mine=${plan_root:0:7} ;; esac
      if [ "$(plan_field "$other" "$field")" != "$mine" ]; then
        hp_unlock; echo "status=spec-branch-mismatch expected=$(plan_field "$other" integration) plan=$(basename "${d%/}")"; return 9
      fi
    done
  done
  printf 'plan: integration %s code-root %s plan-ref %s plan-root %s spec %s\n' "$integration" "${code_root:0:7}" "$plan_ref" "${plan_root:0:7}" "$spec" >> "$ledger" || { hp_unlock; echo "status=error"; return 2; }
  hp_unlock
  echo "status=registered integration=$integration plan-ref=$plan_ref"
}
```

In `cmd_verify`, after `hp_unlock` and before `verify_ledger`, add the branch check:

```bash
  line=$(plan_line_of "$copy")
  if [ -n "$line" ]; then
    cur=$(git -C "$code" branch --show-current 2>/dev/null)
    integ=$(plan_field "$line" integration)
    case "$cur" in
      ""|"$integ"|"$integ.$(ws8_of "$WS").task-"*) ;;
      *) rm -f "$copy"; echo "status=wrong-branch expected=$integ"; return 9 ;;
    esac
  fi
```

(declare `line cur integ` in `cmd_verify`'s `local` list). Add `register) cmd_register "$@" ;;` to the dispatch.

In `cmd_deps` (Task 1): add `code=""` to its locals, the case arm `--code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;`, and, directly after the line that defaults `ledger`, `code=$(code_repo_arg "$code" "$ledger") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }` (unconditionally: an omitted option resolves the cwd's repository, as every code-ref subcommand does); the usage line becomes `deps PLAN_FILE [--check] [--ledger FILE] [--from FILE] [--code-repo DIR]` in both places.

- [ ] **Step 6: Run the section to verify it passes**

Run: `bash ~/.cache/hyperpowers/pd-register-harness.sh`
Expected: every `register` check prints `[PASS]`.

- [ ] **Step 7: Run the common and contract suites, lint, commit**

Run: `bash tests/sdd/test-sdd-common.sh` (expected: `STATUS: PASSED`; `hp_unlock`'s new shape must keep the lock fixtures green), `bash tests/shell-lint/test-lint-shell.sh`, the leak scan.

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): register writes the plan line under both locks, verify reports a stray branch, and the lock pair orders by key"
```

### Task 3: Dependency-aware claims that carry the task branch

**Risk tier:** high — the claim is a durable record under the lock, and this task adds a code-ref write and two crash boundaries to it.

**Depends on:** Task 2


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`owner_record`, `cmd_claim`, usage)
- Test: `tests/sdd/test-sdd-state.sh` (section `claim: dependencies and branches`)

**Interfaces:**
- Consumes: `authoritative_plan_blob`, `hp_plan_graph`, `plan_line_of`, `plan_field`, `ws8_of`, `code_repo_arg`, `hp_lease_key` (Tasks 1 and 2); `open_claims`.
- Produces: `owner_record <sid> [<task branch> <from sha>]` writes `branch=<task ref>` and `from=<sha>` after `time=` when given, as the spec names them; the session's checked-out branch, which the record called `branch=` until now, is written as `checkout=` (its one reader outside `owner_record` is the suite's assertion at `tests/sdd/test-sdd-state.sh:599`, which this task changes to `^checkout=main$`). `claim` takes `hp_lock_pair "$PLAN_DIR" "$code"` whenever the ledger has a plan line and `hp_lock "$PLAN_DIR"` otherwise, resolving `--code-repo` through `code_repo_arg` with the ledger first (`status=wrong-repo`, exit 9, nothing written). `claim PLAN_FILE N --session SID [--takeover] [--code-repo DIR]`: `status=blocked task=<N> waiting=<list> plan=<sha7>` (exit 7, nothing written); on `claimed` with a plan line, `status=claimed task=<N> branch=<ref> from=<sha7>` after creating `<ref>` at `from` in the code repository and appending `Task <N>: branch <ref> from <sha7>`; without a plan line, `status=claimed task=<N> branch=none` and no branch; `own=1` completes a missing branch or ledger line and repeats `branch=`/`from=`; `status=branch-closing` (exit 15) when the integration branch's lease is closing; a takeover's branch is `<ref>.<k>`. Crash seams `claim-after-rename`, `claim-after-branch`. `claim_task_branch_name <integration> <ws8> <N> [<k>]` prints the ref. `write_activity <sid>` writes `plans/<ws>/activity/<sid>` by write-beside-rename (defined here, reused by Tasks 7 and 8).

**Mirror:** `sdd-state:126-193` (`cmd_claim` as it stands); `sdd-state:83-92` (`owner_record`).

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "claim: dependencies and branches"
make_pair cl; cl_a=$PAIR_A
mkdir -p "$cl_a/docs"; : > "$cl_a/docs/spec.md"
cat > "$cl_a/docs/plan.md" <<'PLAN'
# P

**Spec:** docs/spec.md

### Task 1: A

**Risk tier:** standard

**Depends on:** none

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

### Task 3: C

**Risk tier:** standard

**Depends on:** none

### Task 4: D

**Risk tier:** standard

**Depends on:** none
PLAN
git -C "$cl_a" add docs; git -C "$cl_a" commit -qm plan; git -C "$cl_a" push -q origin main 2>/dev/null; git -C "$cl_a" switch -q -c feat
run_state "$cl_a" sync docs/plan.md >/dev/null 2>&1; wscl=$(run_sdd_dir "$cl_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wscl/progress.md"
run_state "$cl_a" register docs/plan.md --session s1 --integration feat >/dev/null
ws8cl=$(basename "$wscl" | sed 's/.*-//'); H0=$(git -C "$cl_a" rev-parse feat)
make_repo "$TEST_ROOT/foreign-cl"
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 --code-repo "$TEST_ROOT/foreign-cl" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ ! -d "$wscl/claims/task-1" ]; then pass "a claim refuses a foreign code repository before writing"; else fail "claim wrong-repo (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "${out%% plan=*}" = "status=blocked task=2 waiting=1" ] && [ ! -d "$wscl/claims/task-2" ]; then pass "a task whose predecessor is incomplete is blocked and nothing is written"; else fail "blocked (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=feat.$ws8cl.task-1 from=${H0:0:7}" ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-1")" = "$H0" ] && grep -q "^Task 1: branch feat.$ws8cl.task-1 from ${H0:0:7}$" "$wscl/progress.md" && grep -q "^branch=feat.$ws8cl.task-1$" "$wscl/claims/task-1/owner" && [ -f "$wscl/activity/s1" ]; then pass "a claim creates the task branch at the integration head, records it and stamps activity"; else fail "claim creates the branch (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 1 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=1 owner=s1 own=1 branch=feat.$ws8cl.task-1 from=${H0:0:7}" ]; then pass "the owner's re-claim repeats the branch"; else fail "own re-claim (rc=$rc: $out)"; fi
# A crash after the rename: the retry creates the branch and the line.
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s1 2>/dev/null); rc=$?
git -C "$cl_a" branch -D "feat.$ws8cl.task-3" >/dev/null 2>&1; sed -i '' '/^Task 3: branch/d' "$wscl/progress.md" 2>/dev/null || sed -i '/^Task 3: branch/d' "$wscl/progress.md"
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% owner=*}" = "status=held task=3" ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-3" >/dev/null && grep -q '^Task 3: branch' "$wscl/progress.md"; then pass "the owner's retry completes a missing branch and ledger line"; else fail "own retry completes (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wscl/progress.md"
( cd "$cl_a" && HYPERPOWERS_TEST_CRASH_AT=claim-after-rename bash "$SDD_STATE" claim docs/plan.md 2 --session s1 >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ -d "$wscl/claims/task-2" ] && ! git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-2" >/dev/null; then pass "the crash seam stops after the rename with no branch yet"; else fail "crash after rename (rc=$rc)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 2 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-2" >/dev/null && grep -q '^Task 2: branch' "$wscl/progress.md"; then pass "the retry after the crash finishes the claim"; else fail "retry after crash (rc=$rc: $out)"; fi
# A crash after the branch: the branch exists, the ledger line is owed; the retry appends it.
( cd "$cl_a" && HYPERPOWERS_TEST_CRASH_AT=claim-after-branch bash "$SDD_STATE" claim docs/plan.md 4 --session s1 >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-4" >/dev/null && ! grep -q '^Task 4: branch' "$wscl/progress.md"; then pass "the crash seam after the branch leaves the ledger line owed"; else fail "crash after branch (rc=$rc)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 4 --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% owner=*}" = "status=held task=4" ] && grep -q "^Task 4: branch feat.$ws8cl.task-4 from " "$wscl/progress.md"; then pass "the retry after the branch crash appends the line"; else fail "retry after branch crash (rc=$rc: $out)"; fi
# A losing claimant creates no branch; a takeover gets task-N.2 from the old head.
git -C "$cl_a" commit -q --allow-empty -m "work on 3" --no-verify 2>/dev/null; git -C "$cl_a" update-ref "refs/heads/feat.$ws8cl.task-3" HEAD
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && ! git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-3.2" >/dev/null; then pass "a losing claimant creates no branch"; else fail "loser no branch (rc=$rc: $out)"; fi
out=$(run_state "$cl_a" claim docs/plan.md 3 --session s2 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% from=*}" = "status=claimed task=3 takeover=1 branch=feat.$ws8cl.task-3.2" ] && [ "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3.2")" = "$(git -C "$cl_a" rev-parse "feat.$ws8cl.task-3")" ] && git -C "$cl_a" rev-parse -q --verify "feat.$ws8cl.task-3" >/dev/null; then pass "a takeover branches task-3.2 from the old head and leaves the old branch"; else fail "takeover branch (rc=$rc: $out)"; fi
# Two sibling plans both claiming Task 1 create distinct branches.
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: Z\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$cl_a/docs/plan2.md"; git -C "$cl_a" add docs; git -C "$cl_a" commit -qm plan2
wscl2=$(run_sdd_dir "$cl_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wscl2/progress.md"; run_state "$cl_a" register docs/plan2.md --session s3 --integration feat >/dev/null
out=$(run_state "$cl_a" claim docs/plan2.md 1 --session s3 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out#*branch=}" != "${out#*branch=feat.$ws8cl.}" ] && git -C "$cl_a" rev-parse -q --verify "feat.$(basename "$wscl2" | sed 's/.*-//').task-1" >/dev/null; then pass "sibling plans' Task 1 branches carry their own ws8"; else fail "sibling branch names (rc=$rc: $out)"; fi
# A plan without a plan line keeps today's claim: no branch.
make_repo "$TEST_ROOT/cl0"; mkdir -p "$TEST_ROOT/cl0/docs"; printf '# P\n\n### Task 1: A\n\n**Risk tier:** standard\n' > "$TEST_ROOT/cl0/docs/plan.md"; git -C "$TEST_ROOT/cl0" add docs; git -C "$TEST_ROOT/cl0" commit -qm plan
ws0=$(ws_path "$TEST_ROOT/cl0" "$TEST_ROOT/cl0/docs/plan.md"); mkdir -p "$ws0"; printf '# SDD ledger — plan: docs/plan.md\n' > "$ws0/progress.md"
out=$(run_state "$TEST_ROOT/cl0" claim docs/plan.md 1 --session s9 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=claimed task=1 branch=none" ]; then pass "a claim without a plan line creates no branch"; else fail "no plan line (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the section to verify it fails**

Extracted harness `~/.cache/hyperpowers/pd-claim-harness.sh` (lines 1-67, the Task 1 and 2 helper sections are not needed: `register` and `deps` are read from the script under test). Expected: every check `[FAIL]`.

- [ ] **Step 3: `owner_record` and `cmd_claim`**

Replace `owner_record` (`sdd-state:83-92`):

```bash
owner_record() { # <sid> [<task branch> <from sha>]
  local top b
  [ -z "${HYPERPOWERS_TEST_FAIL_OWNER_WRITE:-}" ] || return 1
  top=$(git rev-parse --show-toplevel 2>/dev/null) || top=$(pwd -P)
  b=$(git branch --show-current 2>/dev/null)
  [ -n "$b" ] || b="detached@$(git rev-parse --short=7 HEAD 2>/dev/null || echo none)"
  # checkout= is the session's own branch, for the board; branch= is the
  # task branch the claim owns, the name the spec gives it.
  printf 'session=%s\nworktree=%s\ncheckout=%s\nhost=%s\ntime=%s\n' "$1" "$top" "$b" "$(hostname)" "$(hp_utc_now)"
  # The task branch is part of the claim: written before the rename, so a
  # crash between the rename and the branch creation leaves the retry its
  # intended name and base.
  [ -z "${2:-}" ] || printf 'branch=%s\nfrom=%s\n' "$2" "$3"
}
claim_task_branch_name() { # <integration> <ws8> <N> [<k>] -> <integration>.<ws8>.task-<N>[.<k>]
  printf '%s.%s.task-%s%s' "$1" "$2" "$3" "${4:+.$4}"
}
write_activity() { # <sid>
  mkdir -p "$WSDIR/activity" && printf '%s\n' "$(hp_utc_now)" > "$WSDIR/activity/$1.new" && mv -f "$WSDIR/activity/$1.new" "$WSDIR/activity/$1"
}
```

In `cmd_claim`, add `--code-repo` parsing (`code=""`) and these locals: `graph pair tmp blob deps d waiting line integ ref from k prev_ref tb branch_out lease`. Replace the lock line `hp_lock "$PLAN_DIR" || return 2` (`sdd-state:147`) with the choice below, which reads the plan line before any lock so that a claim that will write a code ref holds both locks in the pair's order; the `recover_apply`, `no-workspace` and `done` checks that follow it are unchanged:

```bash
  # A claim with a plan line writes a code ref, so it holds both repositories'
  # locks in the pair's order; without one it writes only state.
  line=$(plan_line_of "$WSDIR/progress.md"); integ=""; ref=""; from=""
  if [ -n "$line" ]; then
    integ=$(plan_field "$line" integration)
    code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
    hp_lock_pair "$PLAN_DIR" "$code" || return 2
  else
    hp_lock "$PLAN_DIR" || return 2
  fi
```

After the `done` check (`sdd-state:150-152`) insert:

```bash
  pair=$(authoritative_plan_blob) || { hp_unlock; echo "status=error"; return 2; }
  blob=${pair%% *}; tmp=${pair#* }
  graph=$(hp_plan_graph "$tmp"); rc=$?; rm -f "$tmp"
  [ "$rc" -eq 0 ] || { hp_unlock; echo "status=invalid plan=${blob:0:7}"; return 2; }
  deps=$(printf '%s\n' "$graph" | sed -n "s/^task=$n depends=//p")
  [ -n "$deps" ] || { hp_unlock; echo "sdd-state: task $n is not in the plan" >&2; echo "status=error"; return 2; }
  waiting=""
  if [ "$deps" != none ]; then
    for d in $(printf '%s' "$deps" | tr ',' ' '); do
      grep -Eq "(^|[^A-Za-z0-9])Task $d: complete" "$WSDIR/progress.md" || waiting="$waiting,$d"
    done
  fi
  if [ -n "$waiting" ]; then hp_unlock; echo "status=blocked task=$n waiting=${waiting#,} plan=${blob:0:7}"; return 7; fi
  if [ -n "$line" ]; then
    lease=$(hp_lease_key "$PLAN_DIR" "$integ")
    if [ -f "$lease" ] && [ "$(sed -n 's/^closing=//p' "$lease")" = 1 ]; then hp_unlock; echo "status=branch-closing"; return 15; fi
    from=$(git -C "$code" rev-parse -q --verify "refs/heads/$integ^{commit}" 2>/dev/null) || { hp_unlock; echo "sdd-state: the integration branch $integ does not exist in $code" >&2; echo "status=error"; return 2; }
    ref=$(claim_task_branch_name "$integ" "$(ws8_of "$WS")" "$n")
  fi
```

Replace the takeover branch of `cmd_claim` so that it computes `task-<N>.<k>`:

```bash
  if [ "$takeover" -eq 1 ] && [ -d "$target" ]; then
    if [ -n "$ref" ]; then
      prev_ref=$(sed -n 's/^branch=//p' "$target/owner" 2>/dev/null)
      k=2; while git -C "$code" rev-parse -q --verify "refs/heads/$ref.$k" >/dev/null 2>&1; do k=$((k + 1)); done
      if [ -n "$prev_ref" ] && tb=$(git -C "$code" rev-parse -q --verify "refs/heads/$prev_ref^{commit}" 2>/dev/null); then from=$tb; fi
      ref="$ref.$k"
    fi
    if ! owner_record "$sid" "$ref" "$from" > "$target/owner.new"; then rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; fi
    prev=$(cat "$target/owner" 2>/dev/null)
    if ! printf -- '--- superseded at %s\n%s\n' "$(hp_utc_now)" "$prev" >> "$target/owner.history"; then rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; fi
    if ! mv -f "$target/owner.new" "$target/owner"; then rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; fi
    if [ "$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)" != "$sid" ]; then hp_unlock; echo "status=error"; return 2; fi
    claim_finish_branch || { hp_unlock; echo "status=error"; return 2; }
    hp_unlock
    echo "status=claimed task=$n takeover=1${branch_out}"; return 0
  fi
```

Replace the publish and the `own=1` paths:

```bash
  tmp=$(mktemp -d "$claims/.tmp-XXXXXX") || { hp_unlock; echo "status=error"; return 2; }
  if ! owner_record "$sid" "$ref" "$from" > "$tmp/owner"; then rm -rf "$tmp"; hp_unlock; echo "status=error"; return 2; fi
  node -e 'const fs=require("fs");try{fs.renameSync(process.argv[1],process.argv[2]);}catch(e){process.exit(e.code==="ENOTEMPTY"||e.code==="EEXIST"?4:2);}' "$tmp" "$target"; rc=$?
  if [ "$rc" -eq 0 ]; then
    if [ "$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)" != "$sid" ]; then hp_unlock; echo "status=error"; return 2; fi
    if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = claim-after-rename ]; then hp_unlock; exit 99; fi
    claim_finish_branch || { hp_unlock; echo "status=error"; return 2; }
    hp_unlock; echo "status=claimed task=$n${branch_out}"; return 0
  fi
  rm -rf "$tmp"
  if [ "$rc" -ne 4 ]; then hp_unlock; echo "status=error"; return 2; fi
  owner=$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)
  since=$(sed -n 's/^time=//p' "$target/owner" 2>/dev/null)
  wt=$(sed -n 's/^worktree=//p' "$target/owner" 2>/dev/null)
  if [ -z "$owner" ]; then hp_unlock; echo "status=error"; return 2; fi
  if [ "$owner" = "$sid" ]; then
    # The owner's retry completes whatever a crash left undone.
    ref=$(sed -n 's/^branch=//p' "$target/owner" 2>/dev/null); from=$(sed -n 's/^from=//p' "$target/owner" 2>/dev/null)
    if [ -n "$ref" ]; then claim_finish_branch || { hp_unlock; echo "status=error"; return 2; }; fi
    hp_unlock; echo "status=held task=$n owner=$owner own=1${branch_out}"; return 0
  fi
  hp_unlock
  echo "status=held task=$n owner=$owner since=$since worktree=$(enc "$wt")"
  return 4
```

And the helper, defined inside `cmd_claim` before its first use (a nested function, as `stamp_fetched` is in `cmd_sync`):

```bash
  # Creates the task branch at its base and records it, idempotently: a
  # branch already at its base or past it is kept, one elsewhere is an error.
  claim_finish_branch() {
    local have
    branch_out=""
    [ -n "$ref" ] || { branch_out=" branch=none"; return 0; }
    if have=$(git -C "$code" rev-parse -q --verify "refs/heads/$ref^{commit}" 2>/dev/null); then
      [ "$have" = "$from" ] || git -C "$code" merge-base --is-ancestor "$from" "$have" 2>/dev/null || { echo "sdd-state: $ref exists at ${have:0:7}, not at or past its recorded base ${from:0:7}" >&2; return 1; }
    else
      git -C "$code" branch "$ref" "$from" >/dev/null 2>&1 || return 1
    fi
    if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = claim-after-branch ]; then hp_unlock; exit 99; fi
    grep -q "^Task $n: branch $ref from ${from:0:7}$" "$WSDIR/progress.md" || printf 'Task %s: branch %s from %s\n' "$n" "$ref" "${from:0:7}" >> "$WSDIR/progress.md" || return 1
    write_activity "$sid"
    branch_out=" branch=$ref from=${from:0:7}"
  }
```

Usage line: `claim PLAN_FILE N --session SID [--takeover] [--code-repo DIR]`.

- [ ] **Step 4: Run the section to verify it passes**

Run the harness. Expected: every check `[PASS]`; the earlier claim fixtures (`c1`, the two-process race) still pass because a ledger without a plan line takes the `branch=none` path, once the suite's owner-record assertion at `tests/sdd/test-sdd-state.sh:599` reads `^checkout=main$` instead of `^branch=main$`.

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): a claim is blocked until its predecessors complete and carries the task branch it creates"
```

### Task 4: `next`, the claimable frontier

**Risk tier:** high — a read-only classification that decides what every session works on; the controller trusts it without checking.

**Depends on:** Task 3


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_next`, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `next`)

**Interfaces:**
- Consumes: `authoritative_plan_blob`, `hp_plan_graph`; claims under `$WSDIR/claims/task-*/owner`; completion lines; the ledger's newest `session <SID>: tasks <list>` line.
- Produces: `sdd-state next PLAN_FILE --session SID [--code-repo DIR]` prints exactly one of `status=next tasks=<list> own-blocked=<list or none> plan=<sha7>`, `status=none reason=complete`, `status=none reason=own-blocked task=<N> waiting=<M or M@sid,...>`, `status=none reason=assigned-complete remaining=<list|none>`, `status=none reason=held held=<N@sid,...> waiting=<list|none>`, `status=none reason=blocked waiting=<list> excluded=<list|none> held=<N@sid,...|none>` (this `held=` names every open task another session holds, allowed or excluded, so the reader knows whom to wait for), exit 0 in every case; `--code-repo`, or the cwd's repository when omitted, is validated through `code_repo_arg` with the ledger (`status=wrong-repo`, exit 9) and otherwise unused. Assignment comes first: a task outside the session's list is `excluded` whatever its graph state, so an allowed task whose incomplete predecessor is outside the list waits on an exclusion and the answer is `blocked`, never `held`. `task_class <N>` (internal) returns one of `claimable own-blocked held waiting-on-held waiting-on-own-blocked waiting-on-excluded waiting-on-open excluded complete`. `next_classify <sid>` (internal) prints the same status line from the globals `resolve_plan` set, with no argument parsing and no code-repository check; `board` (Task 8) calls it in-process for its frontier, so the board needs no code repository to compute one.

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "next: the claimable frontier"
make_pair nx; nx_a=$PAIR_A
mkdir -p "$nx_a/docs"; : > "$nx_a/docs/spec.md"
cat > "$nx_a/docs/plan.md" <<'PLAN'
# P

**Spec:** docs/spec.md

### Task 1: A

**Risk tier:** standard

**Depends on:** none

### Task 2: B

**Risk tier:** standard

**Depends on:** Task 1

### Task 3: C

**Risk tier:** standard

**Depends on:** none

### Task 4: D

**Risk tier:** standard

**Depends on:** Task 3

### Task 5: E

**Risk tier:** standard

**Depends on:** Task 2, Task 4
PLAN
git -C "$nx_a" add docs; git -C "$nx_a" commit -qm plan; git -C "$nx_a" push -q origin main 2>/dev/null; git -C "$nx_a" switch -q -c feat
run_state "$nx_a" sync docs/plan.md >/dev/null 2>&1; wsnx=$(run_sdd_dir "$nx_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsnx/progress.md"
run_state "$nx_a" register docs/plan.md --session s1 --integration feat >/dev/null
make_repo "$TEST_ROOT/foreign-nx"
out=$(run_state "$nx_a" next docs/plan.md --session s1 --code-repo "$TEST_ROOT/foreign-nx" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "next refuses a foreign --code-repo"; else fail "next wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign-nx" && bash "$SDD_STATE" next "$nx_a/docs/plan.md" --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "next run from a foreign repository without --code-repo is wrong-repo"; else fail "next foreign cwd (rc=$rc: $out)"; fi
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1,3 own-blocked=none" ]; then pass "the frontier is the tasks with no incomplete predecessor, in plan order"; else fail "frontier (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 1 --session s1 >/dev/null; run_state "$nx_a" claim docs/plan.md 3 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=1 own-blocked=none" ]; then pass "this session's own claim is listed first and a held task is not listed"; else fail "own first (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=2 own-blocked=none" ]; then pass "a completed predecessor opens its dependent"; else fail "dependent opens (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 2 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=held held=2@s2,3@s2 waiting=4,5" ]; then pass "every open task held or waiting on a held one reads held with holders"; else fail "none held (rc=$rc: $out)"; fi
printf 'session s1: tasks 5\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=blocked waiting=5 excluded=2,3,4 held=2@s2,3@s2" ]; then pass "an assigned list narrows the frontier: a predecessor outside the list is an exclusion, and the holders are still named"; else fail "assigned blocked (rc=$rc: $out)"; fi
sed -i '' '/^session s1: tasks 5$/d' "$wsnx/progress.md" 2>/dev/null || sed -i '/^session s1: tasks 5$/d' "$wsnx/progress.md"
printf 'session s1: tasks 4\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=blocked waiting=4 excluded=2,3,5 held=2@s2,3@s2" ]; then pass "an allowed task whose held predecessor is outside the list waits on the exclusion"; else fail "allowed waiting-on-excluded (rc=$rc: $out)"; fi
printf 'Task 3: complete (commits 3333333..4444444, review clean)\nTask 2: complete (commits 5555555..6666666, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=4 own-blocked=none" ]; then pass "the assigned task becomes claimable when its predecessor completes"; else fail "assigned claimable (rc=$rc: $out)"; fi
printf 'Task 4: complete (commits 7777777..8888888, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=assigned-complete remaining=5" ]; then pass "a finished assigned list reports the remaining tasks"; else fail "assigned-complete (rc=$rc: $out)"; fi
sed -i '' '/^session s1: tasks 4$/d' "$wsnx/progress.md" 2>/dev/null || sed -i '/^session s1: tasks 4$/d' "$wsnx/progress.md"
printf 'session s2: tasks 1,2,3\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=assigned-complete remaining=5" ]; then pass "an excluded open task with complete predecessors is still excluded"; else fail "excluded (rc=$rc: $out)"; fi
# own-blocked: an edge amended onto a claimed task; Task 7 behind it is a descendant of an own-blocked task and is neither offered nor named.
run_state "$nx_a" claim docs/plan.md 5 --session s1 >/dev/null
sed -i '' 's/^\*\*Depends on:\*\* Task 2, Task 4$/**Depends on:** Task 2, Task 4, Task 6/' "$nx_a/docs/plan.md" 2>/dev/null || sed -i 's/^\*\*Depends on:\*\* Task 2, Task 4$/**Depends on:** Task 2, Task 4, Task 6/' "$nx_a/docs/plan.md"
printf '\n### Task 6: F\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 7: G\n\n**Risk tier:** standard\n\n**Depends on:** Task 5\n' >> "$nx_a/docs/plan.md"
git -C "$nx_a" add docs; git -C "$nx_a" commit -qm amend
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=6 own-blocked=5" ]; then pass "a claimable task is offered, the own-blocked task is named, and its descendant is neither"; else fail "own-blocked with frontier (rc=$rc: $out)"; fi
run_state "$nx_a" claim docs/plan.md 6 --session s2 >/dev/null
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=own-blocked task=5 waiting=6@s2" ]; then pass "an own claim whose new predecessor is held reads own-blocked"; else fail "own-blocked (rc=$rc: $out)"; fi
printf 'Task 6: complete (commits 9999999..aaaaaaa, review clean)\nTask 5: complete (commits bbbbbbb..ccccccc, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% plan=*}" = "status=next tasks=7 own-blocked=none" ]; then pass "the descendant opens once the own-blocked task completes"; else fail "descendant opens (rc=$rc: $out)"; fi
printf 'Task 7: complete (commits ddddddd..eeeeeee, review clean)\n' >> "$wsnx/progress.md"
out=$(run_state "$nx_a" next docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=none reason=complete" ]; then pass "every task complete reads complete"; else fail "complete (rc=$rc: $out)"; fi
# A plan line whose ref does not carry the plan file is an error, never a read of the worktree copy.
printf '# U\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$nx_a/docs/unc.md"
wsunc=$(run_sdd_dir "$nx_a" docs/unc.md 2>/dev/null); printf '# SDD ledger — plan: docs/unc.md\n' > "$wsunc/progress.md"
run_state "$nx_a" register docs/unc.md --session s9 --integration feat >/dev/null
err=$(run_state "$nx_a" next docs/unc.md --session s9 2>&1 >"$TEST_ROOT/nx.unc"); rc=$?
if [ "$rc" -eq 2 ] && [ "$(cat "$TEST_ROOT/nx.unc")" = "status=error" ] && printf '%s' "$err" | grep -q 'does not carry docs/unc.md'; then pass "a registered plan its ref does not carry is an error, not a worktree read"; else fail "uncommitted registered plan (rc=$rc: $(cat "$TEST_ROOT/nx.unc"): $err)"; fi
rm -f "$nx_a/docs/unc.md"; rm -rf "$wsunc"
```

- [ ] **Step 2: Run the section to verify it fails**

Harness `~/.cache/hyperpowers/pd-next-harness.sh`. Expected: every check `[FAIL]`.

- [ ] **Step 3: `cmd_next`**

```bash
# --- next --------------------------------------------------------------------
# Classifies every open task of the authoritative plan. The assignment split
# comes first: a task outside the session's assigned list is excluded
# whatever its graph state. Every allowed task is then claimable,
# own-blocked, held, or waiting, and the waiting kind is the first kind
# found in the order held, own-blocked, excluded, open over its incomplete
# predecessors, transitively. The classification is total, so the status
# below is defined for every ledger. Bash 3.2 has no associative arrays, so
# the three maps are variables named by task number (digits only, which is
# what makes the eval safe).
map_set() { eval "MAP_$1_$2=\$3"; }                  # map_set DEP 5 "1,3"
map_get() { eval "printf '%s' \"\${MAP_$1_$2:-}\""; } # map_get DEP 5
cmd_next() {
  local plan="" sid="" code="" rc
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$sid" ] || usage
  resolve_plan "$plan"
  [ -f "$WSDIR/progress.md" ] || { echo "status=no-workspace"; return 2; }
  code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  next_classify "$sid"
}
# <sid> -> the status line, from the resolved plan's state alone. The board
# calls this directly rather than the subcommand, so a board run from a cwd
# that is no repository still computes the frontier.
next_classify() {
  local sid=$1 pair blob tmp graph t deps cls assigned="" line n_list own_list held_list wait_list excl_list waitown_list remaining held_all open_any=0 p rc
  pair=$(authoritative_plan_blob) || { echo "status=error"; return 2; }
  blob=${pair%% *}; tmp=${pair#* }
  graph=$(hp_plan_graph "$tmp"); rc=$?; rm -f "$tmp"
  [ "$rc" -eq 0 ] || { echo "status=invalid plan=${blob:0:7}"; return 2; }
  assigned=$(grep -E "^session $sid: tasks " "$WSDIR/progress.md" | tail -n 1 | sed 's/^session [^:]*: tasks //; s/ //g')
  while IFS= read -r line; do
    t=${line#task=}; t=${t%% *}; deps=${line#*depends=}
    map_set DEP "$t" "$deps"; map_set CLASS "$t" ""; map_set OWNER "$t" ""
    if grep -Eq "(^|[^A-Za-z0-9])Task $t: complete" "$WSDIR/progress.md"; then map_set CLASS "$t" complete; continue; fi
    open_any=1
    map_set OWNER "$t" "$(sed -n 's/^session=//p' "$WSDIR/claims/task-$t/owner" 2>/dev/null)"
  done <<< "$graph"
  [ "$open_any" -eq 1 ] || { echo "status=none reason=complete"; return 0; }
  allowed() { [ -z "$assigned" ] && return 0; case ",$assigned," in *",$1,"*) return 0 ;; esac; return 1; }
  # Classes resolve recursively through the predecessors; a valid graph has
  # no cycle, so the recursion ends.
  classify() { # <task> -> sets CLASS[task]
    local task=$1 kinds="" p pc owner
    [ -z "$(map_get CLASS "$task")" ] || return 0
    if ! allowed "$task"; then map_set CLASS "$task" excluded; return 0; fi
    if [ "$(map_get DEP "$task")" != none ]; then
      for p in $(map_get DEP "$task" | tr ',' ' '); do
        classify "$p"; pc=$(map_get CLASS "$p")
        [ "$pc" != complete ] || continue
        case "$pc" in held|waiting-on-held) kinds="$kinds held" ;; own-blocked|waiting-on-own-blocked) kinds="$kinds own" ;; excluded|waiting-on-excluded) kinds="$kinds excluded" ;; *) kinds="$kinds open" ;; esac
      done
    fi
    owner=$(map_get OWNER "$task")
    if [ -n "$owner" ] && [ "$owner" != "$sid" ]; then map_set CLASS "$task" held; return 0; fi
    if [ -z "$kinds" ]; then map_set CLASS "$task" claimable; return 0; fi
    if [ -n "$owner" ]; then map_set CLASS "$task" own-blocked; return 0; fi
    case " $kinds " in *" held "*) map_set CLASS "$task" waiting-on-held ;; *" own "*) map_set CLASS "$task" waiting-on-own-blocked ;; *" excluded "*) map_set CLASS "$task" waiting-on-excluded ;; *) map_set CLASS "$task" waiting-on-open ;; esac
  }
  n_list=""; own_list=""; held_list=""; wait_list=""; excl_list=""; waitown_list=""; remaining=""; held_all=""
  while IFS= read -r line; do
    t=${line#task=}; t=${t%% *}
    [ "$(map_get CLASS "$t")" != complete ] || continue
    classify "$t"
    cls=$(map_get CLASS "$t")
    if [ -n "$(map_get OWNER "$t")" ] && [ "$(map_get OWNER "$t")" != "$sid" ]; then held_all="${held_all:+$held_all,}$t@$(map_get OWNER "$t")"; fi
    case "$cls" in
      claimable) if [ "$(map_get OWNER "$t")" = "$sid" ]; then n_list="$t${n_list:+,$n_list}"; else n_list="${n_list:+$n_list,}$t"; fi ;;
      own-blocked) own_list="${own_list:+$own_list,}$t" ;;
      held) held_list="${held_list:+$held_list,}$t@$(map_get OWNER "$t")" ;;
      waiting-on-held) wait_list="${wait_list:+$wait_list,}$t" ;;
      waiting-on-own-blocked) waitown_list="${waitown_list:+$waitown_list,}$t" ;;
      waiting-on-excluded|waiting-on-open) excl_list="${excl_list:+$excl_list,}$t" ;;
      excluded) remaining="${remaining:+$remaining,}$t" ;;
    esac
  done <<< "$graph"
  if [ -n "$n_list" ]; then echo "status=next tasks=$n_list own-blocked=${own_list:-none} plan=${blob:0:7}"; return 0; fi
  if [ -n "$own_list" ] || [ -n "$waitown_list" ]; then
    t=${own_list%%,*}; [ -n "$t" ] || t=${waitown_list%%,*}
    wait_list=""
    for p in $(map_get DEP "$t" | tr ',' ' '); do
      [ "$(map_get CLASS "$p")" != complete ] || continue
      if [ -n "$(map_get OWNER "$p")" ] && [ "$(map_get OWNER "$p")" != "$sid" ]; then wait_list="${wait_list:+$wait_list,}$p@$(map_get OWNER "$p")"; else wait_list="${wait_list:+$wait_list,}$p"; fi
    done
    echo "status=none reason=own-blocked task=$t waiting=$wait_list"; return 0
  fi
  if [ -n "$assigned" ] && [ -z "$held_list" ] && [ -z "$wait_list" ] && [ -z "$excl_list" ]; then echo "status=none reason=assigned-complete remaining=${remaining:-none}"; return 0; fi
  if [ -z "$excl_list" ]; then echo "status=none reason=held held=$held_list waiting=${wait_list:-none}"; return 0; fi
  echo "status=none reason=blocked waiting=$excl_list excluded=${remaining:-none} held=${held_all:-none}"
}
```

`map_set`, `map_get` and `next_classify` are top-level helpers beside `cmd_next`; nothing in the script uses `declare -A`, because the suites run under `/bin/bash` 3.2. Usage line: `next PLAN_FILE --session SID [--code-repo DIR]`; dispatch `next) cmd_next "$@" ;;`.

- [ ] **Step 4: Run the section to verify it passes**

Run the harness under `/bin/bash` (3.2) and under the newest bash on PATH. Expected: every check `[PASS]` on both.

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): next prints the claimable frontier with a total classification of every open task"
```

### Task 5: The final claim, the branch lease, `lease` and `finish --session`

**Risk tier:** high — the writers that decide which session may finish a plan and tear down a branch.

**Depends on:** Task 4


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_claim` for `final`, `cmd_lease`, `cmd_finish`, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `final: claim, lease, finish`)

**Interfaces:**
- Consumes: `hp_lease_key`, `hp_lock_pair`, `plan_line_of`, `plan_field`, `open_claims`, `authoritative_plan_blob`, `hp_plan_graph`.
- Produces: `claim PLAN_FILE final --session SID [--takeover] [--release] [--code-repo DIR]`: `status=claimed task=final lease=<key basename>` (exit 0); `status=blocked task=final waiting=<open tasks>` (exit 7); `status=held task=final owner=<sid> since=<UTC>` (exit 4) for another session's final claim of this plan; `status=held task=final lease=<sid> plan=<ws>` (exit 4) when the branch lease belongs to another plan's session (this plan's `claims/final` stays); the holder's repeat answers `status=held task=final owner=<sid> own=1 lease=<key basename>` (exit 0) and leaves the lease exactly as it is, `closing=` included; `--takeover` rewrites both records; `--release` removes this session's `claims/final` and lease (`status=released`); with no plan line the lease is skipped and the answer is `status=claimed task=final lease=none`. `claim final` runs under the lock pair the claim's lock choice (Task 3) takes whenever a plan line exists. `lease PLAN_FILE (--release|--closing) --session SID [--code-repo DIR]`: `status=released` or `status=no-lease` (exit 0) for `--release`; `status=closing` (exit 0), `status=sibling-open plan=<ws>` (exit 15), `status=no-lease` (exit 4) for `--closing`. `finish PLAN_FILE --session SID [--force] [--code-repo DIR]`: `status=not-holder owner=<sid>` and `status=no-final-claim` (exit 11) before the inherited checks; `--code-repo`, or the cwd's repository when omitted, is resolved through `code_repo_arg` with the ledger (`status=wrong-repo`, exit 9) before the lock, as `lease`'s is (after `finish`, with no ledger, the check has nothing to compare and `lease` answers from the lease files alone); the lease survives `finish`. Lease record fields: `session=`, `host=`, `plan=<ws>`, `branch=<integration>`, `time=`, `closing=0|1`. `lease_find <ws> <sid>` prints the matching lease file or nothing.

**Mirror:** `cmd_finish` (`sdd-state:701-764`), `cmd_claim`'s takeover path.

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "final: claim, lease, finish"
make_pair fn; fn_a=$PAIR_A
mkdir -p "$fn_a/docs"; : > "$fn_a/docs/spec.md"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fn_a/docs/plan.md"
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fn_a/docs/plan2.md"
git -C "$fn_a" add docs; git -C "$fn_a" commit -qm plans; git -C "$fn_a" push -q origin main 2>/dev/null; git -C "$fn_a" switch -q -c feature/foo
run_state "$fn_a" sync docs/plan.md >/dev/null 2>&1; wsfn=$(run_sdd_dir "$fn_a" docs/plan.md 2>/dev/null); wsfn2=$(run_sdd_dir "$fn_a" docs/plan2.md 2>/dev/null)
printf '# SDD ledger — plan: docs/plan.md\n' > "$wsfn/progress.md"; printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsfn2/progress.md"
run_state "$fn_a" register docs/plan.md --session s1 --integration feature/foo >/dev/null; run_state "$fn_a" register docs/plan2.md --session s2 --integration feature/foo >/dev/null
run_state "$fn_a" claim docs/plan.md 1 --session s1 >/dev/null
out=$(run_state "$fn_a" claim docs/plan.md final --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "$out" = "status=blocked task=final waiting=1" ]; then pass "final is blocked while a task is open"; else fail "final blocked (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsfn/progress.md"
out=$(run_state "$fn_a" claim docs/plan.md final --session s1 2>/dev/null); rc=$?
lease_fn=$(ls "$STATE_ROOT/$(state_key "$fn_a").final-"* 2>/dev/null | head -n 1)
if [ "$rc" -eq 0 ] && [ "${out%% lease=*}" = "status=claimed task=final" ] && [ -n "$lease_fn" ] && [ "$(sed -n 's/^branch=//p' "$lease_fn")" = "feature/foo" ] && [ "$(sed -n 's/^closing=//p' "$lease_fn")" = 0 ] && [ -d "$wsfn/claims/final" ]; then pass "final claims the plan and takes a slash-safe lease on the branch"; else fail "final claimed (rc=$rc: $out: $lease_fn)"; fi
printf 'time=2026-01-01T00:00:00Z\n' >> "$lease_fn"
out=$(run_state "$fn_a" claim docs/plan.md final --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=held task=final owner=s1 own=1 lease=$(basename "$lease_fn")" ] && grep -q '^time=2026-01-01T00:00:00Z$' "$lease_fn"; then pass "the holder's repeated final claim leaves the lease untouched"; else fail "own final re-claim (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" claim docs/plan.md final --session s3 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && [ "${out%% since=*}" = "status=held task=final owner=s1" ]; then pass "a second session of the same plan sees final held"; else fail "final held (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 3333333..4444444, review clean)\n' >> "$wsfn2/progress.md"
out=$(run_state "$fn_a" claim docs/plan2.md final --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && [ "$out" = "status=held task=final lease=s1 plan=$(basename "$wsfn")" ] && [ -d "$wsfn2/claims/final" ]; then pass "a sibling plan's final waits for the branch lease and keeps its own claim"; else fail "sibling lease held (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" finish docs/plan.md --session s3 2>/dev/null); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=not-holder owner=s1" ]; then pass "finish refuses a session that does not hold final"; else fail "finish not-holder (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" finish docs/plan.md --session s3 --force 2>/dev/null); rc=$?
if [ "$rc" -eq 11 ]; then pass "--force does not bypass the final claim"; else fail "force bypass (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" lease docs/plan2.md --closing --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && [ "$out" = "status=no-lease" ]; then pass "closing without the lease is no-lease"; else fail "closing no-lease (rc=$rc: $out)"; fi
make_repo "$TEST_ROOT/foreign-fn"
out=$(run_state "$fn_a" lease docs/plan.md --release --session s1 --code-repo "$TEST_ROOT/foreign-fn" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ -f "$lease_fn" ]; then pass "lease refuses a foreign --code-repo while the ledger exists"; else fail "lease wrong-repo (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" finish docs/plan.md --session s1 --code-repo "$TEST_ROOT/foreign-fn" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ -d "$wsfn" ]; then pass "finish refuses a foreign --code-repo before touching the workspace"; else fail "finish wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign-fn" && bash "$SDD_STATE" finish "$fn_a/docs/plan.md" --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ -d "$wsfn" ]; then pass "finish run from a foreign repository without --code-repo leaves the workspace intact"; else fail "finish foreign cwd (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" lease docs/plan.md --closing --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 15 ] && [ "$out" = "status=sibling-open plan=$(basename "$wsfn2")" ] && [ "$(sed -n 's/^closing=//p' "$lease_fn")" = 0 ]; then pass "closing is refused while a sibling plan is open"; else fail "sibling-open (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" finish docs/plan.md --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsfn" ] && [ -f "$lease_fn" ]; then pass "the holder finishes and the lease survives the workspace"; else fail "holder finishes (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" claim docs/plan2.md final --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ]; then pass "the lease still blocks the sibling after finish"; else fail "lease after finish (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" lease docs/plan.md --release --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=released" ] && [ ! -f "$lease_fn" ]; then pass "release finds the lease by workspace and session with no workspace on disk"; else fail "release after finish (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" lease docs/plan.md --release --session s1 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=no-lease" ]; then pass "a second release is quiet"; else fail "second release (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" claim docs/plan2.md final --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% lease=*}" = "status=claimed task=final" ]; then pass "the sibling takes the lease once released"; else fail "sibling takes lease (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" lease docs/plan2.md --closing --session s2 2>/dev/null); rc=$?
lease_fn2=$(ls "$STATE_ROOT/$(state_key "$fn_a").final-"* | head -n 1)
if [ "$rc" -eq 0 ] && [ "$out" = "status=closing" ] && [ "$(sed -n 's/^closing=//p' "$lease_fn2")" = 1 ]; then pass "the last open plan may close the branch"; else fail "closing (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" claim docs/plan2.md final --session s2 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% lease=*}" = "status=held task=final owner=s2 own=1" ] && [ "$(sed -n 's/^closing=//p' "$lease_fn2")" = 1 ]; then pass "the holder's repeated final claim keeps closing=1"; else fail "own re-claim keeps closing (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" register docs/plan.md --session s4 --integration feature/foo 2>/dev/null); rc=$?
if [ "$rc" -eq 15 ] && [ "$out" = "status=branch-closing" ]; then pass "a registration on a closing branch is refused"; else fail "register branch-closing (rc=$rc: $out)"; fi
printf '# R\n\n**Spec:** docs/spec2.md\n\n### Task 1: C\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fn_a/docs/plan3.md"; : > "$fn_a/docs/spec2.md"; git -C "$fn_a" add docs; git -C "$fn_a" commit -qm plan3
wsfn3=$(run_sdd_dir "$fn_a" docs/plan3.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan3.md\nplan: integration feature/foo code-root %s plan-ref feature/foo plan-root %s spec docs/spec2.md\n' "$(git -C "$fn_a" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7)" "$(git -C "$fn_a" rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7)" > "$wsfn3/progress.md"
out=$(run_state "$fn_a" claim docs/plan3.md 1 --session s5 2>/dev/null); rc=$?
if [ "$rc" -eq 15 ] && [ "$out" = "status=branch-closing" ]; then pass "a task claim on a closing branch is refused"; else fail "claim branch-closing (rc=$rc: $out)"; fi
# A takeover of a dead holder's final and lease, on the explicit flag alone.
out=$(run_state "$fn_a" claim docs/plan2.md final --session s6 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ]; then pass "final is held for a stranger without the flag"; else fail "stranger held (rc=$rc: $out)"; fi
out=$(run_state "$fn_a" claim docs/plan2.md final --session s6 --takeover 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(sed -n 's/^session=//p' "$lease_fn2")" = s6 ] && [ "$(sed -n 's/^session=//p' "$wsfn2/claims/final/owner")" = s6 ] && grep -q 'superseded' "$wsfn2/claims/final/owner.history"; then pass "a takeover moves the final claim and the lease on the flag alone"; else fail "final takeover (rc=$rc: $out)"; fi
# The closing race: the closing pauses between its sibling check and its write while a sibling registers; the locks serialize them, so exactly one succeeds.
rm -rf "$wsfn3"; wsfn3=$(run_sdd_dir "$fn_a" docs/plan3.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan3.md\n' > "$wsfn3/progress.md"
co_fn=$(dirname "$(dirname "$wsfn2")")
: > "$co_fn/.lease-before-close-pause"
( cd "$fn_a" && HYPERPOWERS_TEST_PAUSE_AT=lease-before-close bash "$SDD_STATE" lease docs/plan2.md --closing --session s6 > "$TEST_ROOT/fn.close" 2>/dev/null; echo $? > "$TEST_ROOT/fn.closerc" ) &
n=0; while [ ! -e "$co_fn/.lease-before-close-paused" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
( cd "$fn_a" && bash "$SDD_STATE" register docs/plan3.md --session s7 --integration feature/foo > "$TEST_ROOT/fn.reg" 2>/dev/null; echo $? > "$TEST_ROOT/fn.regrc" ) &
sleep 0.5; rm -f "$co_fn/.lease-before-close-pause"; wait
r1=$(cat "$TEST_ROOT/fn.closerc"); r2=$(cat "$TEST_ROOT/fn.regrc")
if { [ "$r1" = 0 ] && [ "$r2" = 15 ]; } || { [ "$r1" = 15 ] && [ "$r2" = 0 ]; }; then pass "a sibling registering during the closing: exactly one of the two succeeds"; else fail "closing race (rcs $r1 $r2: $(cat "$TEST_ROOT/fn.close") / $(cat "$TEST_ROOT/fn.reg"))"; fi
rm -rf "$wsfn3"
run_state "$fn_a" claim docs/plan2.md final --session s6 --release >/dev/null
out=$(run_state "$fn_a" finish docs/plan2.md --session s6 2>/dev/null); rc=$?
if [ "$rc" -eq 11 ] && [ "$out" = "status=no-final-claim" ] && [ -d "$wsfn2" ]; then pass "finish without a final claim is no-final-claim"; else fail "no-final-claim (rc=$rc: $out)"; fi
# The plan in one repository and the code in another: the claim, the final, the closing, finish and the release after it name the code repository.
make_repo "$TEST_ROOT/fsp"; make_repo "$TEST_ROOT/fsc"; fsp="$TEST_ROOT/fsp"; fsc="$TEST_ROOT/fsc"
mkdir -p "$fsp/docs"; printf '# S\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fsp/docs/plan.md"; : > "$fsp/docs/spec.md"; git -C "$fsp" add docs; git -C "$fsp" commit -qm plan; git -C "$fsp" switch -q -c plans
git -C "$fsc" switch -q -c feat
wsfs=$(run_sdd_dir "$fsp" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsfs/progress.md"; ws8fs=$(basename "$wsfs" | sed 's/.*-//')
run_state "$fsp" register docs/plan.md --session s1 --integration feat --code-repo "$fsc" >/dev/null
out=$(run_state "$fsp" claim docs/plan.md 1 --session s1 --code-repo "$fsc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && git -C "$fsc" rev-parse -q --verify "feat.$ws8fs.task-1" >/dev/null && ! git -C "$fsp" rev-parse -q --verify "feat.$ws8fs.task-1" >/dev/null; then pass "a split claim creates the task branch in the code repository only"; else fail "split claim (rc=$rc: $out)"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\n' >> "$wsfs/progress.md"
out=$(run_state "$fsp" claim docs/plan.md final --session s1 --code-repo "$fsc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% lease=*}" = "status=claimed task=final" ] && ls "$STATE_ROOT/$(state_key "$fsp").final-"* >/dev/null 2>&1; then pass "a split final claim leases the branch beside the plan repository's lock"; else fail "split final (rc=$rc: $out)"; fi
printf '# S2\n\n**Spec:** docs/spec.md\n\n### Task 1: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$fsp/docs/plan2.md"; git -C "$fsp" add docs; git -C "$fsp" commit -qm plan2
wsfs2=$(run_sdd_dir "$fsp" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsfs2/progress.md"
run_state "$fsp" register docs/plan2.md --session s2 --integration feat --code-repo "$fsc" >/dev/null
out=$(run_state "$fsp" lease docs/plan.md --closing --session s1 --code-repo "$fsc" 2>/dev/null); rc=$?
if [ "$rc" -eq 15 ] && [ "$out" = "status=sibling-open plan=$(basename "$wsfs2")" ]; then pass "closing finds the sibling in the plan repository's state when the code lives elsewhere"; else fail "split sibling-open (rc=$rc: $out)"; fi
rm -rf "$wsfs2"
out=$(run_state "$fsp" finish docs/plan.md --session s1 --code-repo "$fsc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=finished" ] && [ ! -d "$wsfs" ]; then pass "the split holder finishes"; else fail "split finish (rc=$rc: $out)"; fi
out=$(run_state "$fsp" lease docs/plan.md --release --session s1 --code-repo "$fsc" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=released" ] && ! ls "$STATE_ROOT/$(state_key "$fsp").final-"* >/dev/null 2>&1; then pass "the release after finish works across repositories with no workspace on disk"; else fail "split release (rc=$rc: $out)"; fi
```

- [ ] **Step 2: Run the section to verify it fails**

Harness `~/.cache/hyperpowers/pd-final-harness.sh`. Expected: every check `[FAIL]`.

- [ ] **Step 3: `claim final`, `lease_find`, `cmd_lease`, and `finish --session`**

In `cmd_claim`, accept `final` as `N` (`case "$n" in final) ;; ''|*[!0-9]*) usage ;; esac`) and `--release`, and branch at the top of the locked region:

```bash
  if [ "$n" = final ]; then claim_final; return $?; fi
```

with the nested function defined before the lock is taken:

```bash
  claim_final() {
    local open line integ lease lease_out tmpl owner since blob pair tmp graph t missing=""
    if [ "$release" -eq 1 ]; then
      if [ -d "$target" ] && [ "$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null)" = "$sid" ]; then rm -rf "$target"; fi
      lease=$(lease_find "$WS" "$sid"); [ -z "$lease" ] || rm -f "$lease"
      hp_unlock; echo "status=released"; return 0
    fi
    # Without a plan line (a plan that predates registration) there is no
    # branch to lease: only claims/final is published.
    line=$(plan_line_of "$WSDIR/progress.md"); integ=""
    [ -z "$line" ] || integ=$(plan_field "$line" integration)
    pair=$(authoritative_plan_blob) || { hp_unlock; echo "status=error"; return 2; }
    tmp=${pair#* }; graph=$(hp_plan_graph "$tmp"); rc=$?; rm -f "$tmp"
    [ "$rc" -eq 0 ] || { hp_unlock; echo "status=invalid"; return 2; }
    for t in $(printf '%s\n' "$graph" | sed 's/^task=\([0-9]*\) .*/\1/'); do
      grep -Eq "(^|[^A-Za-z0-9])Task $t: complete" "$WSDIR/progress.md" || missing="$missing,$t"
    done
    open=$(open_claims); [ -z "$open" ] || missing="$missing,$open"
    if [ -n "$missing" ]; then hp_unlock; echo "status=blocked task=final waiting=$(printf '%s' "${missing#,}" | tr ',' '\n' | sort -nu | paste -sd, -)"; return 7; fi
    if [ -d "$target" ] && [ "$takeover" -eq 0 ]; then
      owner=$(sed -n 's/^session=//p' "$target/owner" 2>/dev/null); since=$(sed -n 's/^time=//p' "$target/owner" 2>/dev/null)
      if [ "$owner" != "$sid" ]; then hp_unlock; echo "status=held task=final owner=$owner since=$since"; return 4; fi
    fi
    lease=""; [ -z "$integ" ] || lease=$(hp_lease_key "$PLAN_DIR" "$integ")
    if [ -n "$lease" ] && [ -f "$lease" ] && [ "$takeover" -eq 0 ]; then
      if [ "$(sed -n 's/^session=//p' "$lease")" = "$sid" ] && [ "$(sed -n 's/^plan=//p' "$lease")" = "$WS" ]; then
        # The holder's repeat: the lease, closing= included, stays as it is.
        [ -d "$target" ] || publish_final_claim || { hp_unlock; echo "status=error"; return 2; }
        hp_unlock; echo "status=held task=final owner=$sid own=1 lease=$(basename "$lease")"; return 0
      fi
      if [ "$(sed -n 's/^session=//p' "$lease")" != "$sid" ] || [ "$(sed -n 's/^plan=//p' "$lease")" != "$WS" ]; then
        # This plan's own claim is published first, so the second finisher
        # keeps its place and retries for the lease.
        [ -d "$target" ] || publish_final_claim || { hp_unlock; echo "status=error"; return 2; }
        hp_unlock; echo "status=held task=final lease=$(sed -n 's/^session=//p' "$lease") plan=$(sed -n 's/^plan=//p' "$lease")"; return 4
      fi
    fi
    if [ -d "$target" ] && [ "$takeover" -eq 1 ]; then
      owner_record "$sid" > "$target/owner.new" || { rm -f "$target/owner.new"; hp_unlock; echo "status=error"; return 2; }
      printf -- '--- superseded at %s\n%s\n' "$(hp_utc_now)" "$(cat "$target/owner" 2>/dev/null)" >> "$target/owner.history" || { hp_unlock; echo "status=error"; return 2; }
      mv -f "$target/owner.new" "$target/owner" || { hp_unlock; echo "status=error"; return 2; }
    elif [ ! -d "$target" ]; then
      publish_final_claim || { hp_unlock; echo "status=error"; return 2; }
    fi
    if [ -n "$lease" ]; then
      printf 'session=%s\nhost=%s\nplan=%s\nbranch=%s\ntime=%s\nclosing=0\n' "$sid" "$(hostname)" "$WS" "$integ" "$(hp_utc_now)" > "$lease.new" || { hp_unlock; echo "status=error"; return 2; }
      mv -f "$lease.new" "$lease" || { hp_unlock; echo "status=error"; return 2; }
    fi
    write_activity "$sid"
    hp_unlock
    lease_out=none; [ -z "$lease" ] || lease_out=$(basename "$lease")
    echo "status=claimed task=final lease=$lease_out${takeover:+ takeover=$takeover}" | sed 's/ takeover=0$//'
  }
  publish_final_claim() {
    local tmpl
    tmpl=$(mktemp -d "$claims/.tmp-XXXXXX") || return 1
    owner_record "$sid" > "$tmpl/owner" || { rm -rf "$tmpl"; return 1; }
    node -e 'const fs=require("fs");try{fs.renameSync(process.argv[1],process.argv[2]);}catch(e){process.exit(e.code==="ENOTEMPTY"||e.code==="EEXIST"?4:2);}' "$tmpl" "$target"; rc=$?
    [ "$rc" -ne 0 ] && rm -rf "$tmpl"
    [ "$rc" -eq 0 ] || [ "$rc" -eq 4 ]
  }
```

(`target` for `final` is `$claims/final`; `release` is a new flag parsed beside `--takeover`; `lease_out` is the lease's basename, or `none` without a plan line.) The blocked check for a numbered task in Task 3 must skip when `n` is `final`.

Top-level helpers and `cmd_lease`, inserted before `# --- prune`:

```bash
# <ws> <sid> -> the lease file whose record names this workspace and session,
# found without a workspace on disk: a release after finish needs only the
# plan path's repository key. Two matches is a state nothing produces.
lease_find() {
  local c f hits=""
  c=$(hp_checkout_path "$PLAN_DIR") || return 1
  for f in "$c".final-*; do
    [ -f "$f" ] || continue
    [ "$(sed -n 's/^plan=//p' "$f")" = "$1" ] && [ "$(sed -n 's/^session=//p' "$f")" = "$2" ] && hits="$hits $f"
  done
  set -- $hits
  [ $# -le 1 ] || { echo "sdd-state: more than one lease names workspace $1 and session $2: $hits" >&2; return 2; }
  printf '%s\n' "${1:-}"
}
cmd_lease() {
  local plan="" sid="" code="" op="" lease integ d other rc
  while [ $# -gt 0 ]; do
    case "$1" in
      --release|--closing) op=${1#--}; shift ;;
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$sid" ] && [ -n "$op" ] || usage
  resolve_plan "$plan"
  # After finish there is no ledger, so the code-root check has nothing to
  # compare and the lease is found by identity alone.
  code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  hp_lock_pair "$PLAN_DIR" "$code" || return 2
  lease=$(lease_find "$WS" "$sid"); rc=$?
  [ "$rc" -eq 0 ] || { hp_unlock; echo "status=error"; return 2; }
  if [ -z "$lease" ]; then hp_unlock; echo "status=no-lease"; [ "$op" = release ] && return 0; return 4; fi
  if [ "$op" = release ]; then rm -f "$lease"; hp_unlock; echo "status=released"; return 0; fi
  integ=$(sed -n 's/^branch=//p' "$lease")
  if [ "${HYPERPOWERS_TEST_PAUSE_AT:-}" = lease-before-close ]; then
    : > "$CO/.lease-before-close-paused"; while [ -e "$CO/.lease-before-close-pause" ]; do sleep 0.1; done; rm -f "$CO/.lease-before-close-paused"
  fi
  for d in "$ROOT"/plans/*/; do
    [ -f "$d/progress.md" ] || continue; [ "${d%/}" != "$WSDIR" ] || continue
    other=$(plan_line_of "$d/progress.md"); [ -n "$other" ] || continue
    if [ "$(plan_field "$other" integration)" = "$integ" ]; then hp_unlock; echo "status=sibling-open plan=$(basename "${d%/}")"; return 15; fi
  done
  sed 's/^closing=.*/closing=1/' "$lease" > "$lease.new" && mv -f "$lease.new" "$lease" || { hp_unlock; echo "status=error"; return 2; }
  hp_unlock; echo "status=closing"
}
```

In `cmd_finish`: parse `--session SID` (required: `[ -n "$sid" ] || usage`) and `--code-repo DIR` (`code=""`, added only if `cmd_finish` does not take it yet); before the lock, `code=$(code_repo_arg "$code" "$(ledger_path)") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }` (unconditionally, so a session whose cwd is the wrong repository cannot delete the workspace); and after `recover_apply` and before the removal-copy loop:

```bash
  if [ ! -d "$WSDIR/claims/final" ]; then hp_unlock; echo "status=no-final-claim"; return 11; fi
  owner=$(sed -n 's/^session=//p' "$WSDIR/claims/final/owner" 2>/dev/null)
  if [ "$owner" != "$sid" ]; then hp_unlock; echo "status=not-holder owner=$owner"; return 11; fi
```

The existing `finish` fixtures of the suite gain `--session <sid>` and a preceding `claim ... final` where they finish a plan; where a fixture finishes a plan with no plan line, `claim final` needs none: make `claim_final` skip the lease when the ledger has no plan line (`lease=""`), publishing only `claims/final`. Usage lines: `finish PLAN_FILE --session SID [--force] [--code-repo DIR]`, `lease PLAN_FILE (--release|--closing) --session SID [--code-repo DIR]`, `claim PLAN_FILE (N|final) --session SID [--takeover] [--release] [--code-repo DIR]`; dispatch `lease) cmd_lease "$@" ;;`.

- [ ] **Step 4: Run the section and the existing finish fixtures**

Run the harness, then the whole state suite to a log (`bash tests/sdd/test-sdd-state.sh > ~/.cache/hyperpowers/pd-t5.log 2>&1; echo "suite rc=$?" >> ~/.cache/hyperpowers/pd-t5.log`). Expected: `STATUS: PASSED`, `suite rc=0`.

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): the final train is claimed with a branch lease, and finish refuses any other session"
```

### Task 6: `amend`, the only writer of the plan ref

**Risk tier:** high — a compare-and-swap on a code or plan repository branch, with a transaction record and a crash boundary.

**Depends on:** Task 5


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_amend`, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `amend`)

**Interfaces:**
- Consumes: `authoritative_plan_blob`, `hp_plan_graph`, `hp_plan_overlaps`, `plan_line_of`, `plan_field`, `hp_lease_key`, `hp_git_id`, `hp_git_version_at_least`, `hp_lock`.
- Produces: `sdd-state amend PLAN_FILE --from FILE --base BLOB [--accept 'tasks=A,B path=P'|'tasks=A,B interface=I' ...] [--message SUBJECT] [--code-repo DIR]`, where `BLOB` is the seven-character `plan=` token `deps` prints or a full blob id, resolved through `git rev-parse --verify <id>^{blob}` before any comparison (an ambiguous abbreviation is `status=error` with a stderr line naming the full-id command; an id no object matches is `stale`): `status=amended head=<sha7> plan=<blob sha7>` (exit 0; `already=1` when a retry found the record's commit published); `status=stale base=<sha7> current=<sha7>` (exit 14); `status=invalid plan=<sha7>` (exit 2) and the parser's stderr line; `status=conflicts plan=<sha7> count=<n>` then the conflict lines (exit 1); `status=branch-closing` (exit 15) under a closing lease and `status=checked-out worktree=lease:<sid>` (exit 13) under any other held lease, in that order; `status=wrong-repo` (exit 9) for a `--code-repo`, or an omitted one resolving the cwd, whose root is not the plan line's; `status=error` naming both heads after three lost swaps. The amendment record `plans/<ws>/amends/<candidate blob sha>` holds `base=`, `blob=`, `commit=`, and one `accept=` line per acceptance; it counts for `deps --check` only while its `commit=` is on the plan ref, and it is removed after the ledger lines are appended, on `stale`, and after the third lost swap. Crash seam `amend-after-swap`; writer seam `amend-before-swap:<sha>` (the plan ref is moved to `<sha>` after the record and before the swap, once); a lost swap is recomputed on the moved head, and a moved head whose plan blob is no longer the base is `stale`. The ledger gains `scan: accepted-overlap <accept>` lines and `plan: amended <blob sha7> by <sid>: <subject>` (the session is `hp_session_id`, or `unknown`).

**Mirror:** `hp_commit_paths` (`sdd-common.sh:345-392`) for the temporary-index commit and the three-attempt compare-and-swap; the merge plumbing in `cmd_sync` (`sdd-state:1822-1838`).

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "amend: the plan ref's only writer"
make_pair am; am_a=$PAIR_A
mkdir -p "$am_a/docs"; : > "$am_a/docs/spec.md"
cat > "$am_a/docs/plan.md" <<'PLAN'
# P

**Spec:** docs/spec.md

### Task 1: A

**Risk tier:** standard

**Depends on:** none

**Files:**
- Modify: `src/x.sh`

### Task 2: B

**Risk tier:** standard

**Depends on:** none

**Files:**
- Modify: `src/y.sh`
PLAN
git -C "$am_a" add docs; git -C "$am_a" commit -qm plan; git -C "$am_a" push -q origin main 2>/dev/null; git -C "$am_a" switch -q -c feat
run_state "$am_a" sync docs/plan.md >/dev/null 2>&1; wsam=$(run_sdd_dir "$am_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsam/progress.md"; run_state "$am_a" register docs/plan.md --session s1 --integration feat >/dev/null
base_am=$(git -C "$am_a" rev-parse feat:docs/plan.md); head_am=$(git -C "$am_a" rev-parse feat)
sed 's/^- Modify: `src\/y.sh`$/- Modify: `src\/x.sh`/' "$am_a/docs/plan.md" > "$TEST_ROOT/am.cand1"
make_repo "$TEST_ROOT/foreign-am"
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand1" --base "$base_am" --code-repo "$TEST_ROOT/foreign-am" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ "$(git -C "$am_a" rev-parse feat)" = "$head_am" ]; then pass "amend refuses a foreign --code-repo before anything moves"; else fail "amend wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT/foreign-am" && bash "$SDD_STATE" amend "$am_a/docs/plan.md" --from "$TEST_ROOT/am.cand1" --base "$base_am" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ] && [ "$(git -C "$am_a" rev-parse feat)" = "$head_am" ]; then pass "amend run from a foreign repository without --code-repo is wrong-repo"; else fail "amend foreign cwd (rc=$rc: $out)"; fi
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand1" --base "$base_am" 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "${out%% plan=*}" = "status=conflicts" ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,2 shares=src/x.sh' && [ "$(git -C "$am_a" rev-parse feat)" = "$head_am" ]; then pass "an amendment with an undeclared overlap publishes nothing"; else fail "amend conflicts (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand1" --base "$base_am" --accept 'tasks=1,2 path=src/x.sh' --message "x twice" 2>/dev/null); rc=$?
new_head=$(git -C "$am_a" rev-parse feat)
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$new_head" != "$head_am" ] && [ "$(git -C "$am_a" rev-parse "$new_head^")" = "$head_am" ] && [ "$(git -C "$am_a" show feat:docs/plan.md | grep -c 'src/x.sh')" = 2 ] && [ "$(git -C "$am_a" diff --name-only "$head_am" "$new_head")" = "docs/plan.md" ] && grep -q '^scan: accepted-overlap tasks=1,2 path=src/x.sh$' "$wsam/progress.md" && grep -q '^plan: amended [0-9a-f]\{7\} by .*: x twice$' "$wsam/progress.md" && [ ! -d "$wsam/amends" -o -z "$(ls -A "$wsam/amends" 2>/dev/null)" ]; then pass "an accepted amendment publishes one plan-only commit and its acceptance line"; else fail "amend accepted (rc=$rc: $out)"; fi
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand1" --base "$base_am" 2>/dev/null); rc=$?
if [ "$rc" -eq 14 ] && [ "${out%% current=*}" = "status=stale base=${base_am:0:7}" ]; then pass "an amendment from an old base is stale"; else fail "stale (rc=$rc: $out)"; fi
base2=$(git -C "$am_a" rev-parse feat:docs/plan.md)
sed 's/^\*\*Depends on:\*\* none$/**Depends on:** Task 2/' "$TEST_ROOT/am.cand1" > "$TEST_ROOT/am.cycle"
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cycle" --base "$base2" 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "${out%% *}" = "status=invalid" ] && [ "$(git -C "$am_a" rev-parse feat)" = "$new_head" ]; then pass "an invalid graph is refused before anything moves"; else fail "invalid (rc=$rc: $out)"; fi
# A crash after the swap: the record carries a new acceptance the ledger lacks; deps --check and a fresh amendment in that window honour it; the retry finishes the lines.
awk '{ print } /^- Modify: `src\/x.sh`$/ { print "- Modify: `src/w.sh`" }' "$TEST_ROOT/am.cand1" > "$TEST_ROOT/am.cand3"
( cd "$am_a" && HYPERPOWERS_TEST_CRASH_AT=amend-after-swap bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/am.cand3" --base "$base2" --accept 'tasks=1,2 path=src/w.sh' --message "w twice" >/dev/null 2>&1 ); rc=$?
rec=$(ls "$wsam/amends/" 2>/dev/null | head -n 1)
if [ "$rc" -eq 99 ] && [ -n "$rec" ] && grep -q '^accept=tasks=1,2 path=src/w.sh$' "$wsam/amends/$rec" && [ "$(git -C "$am_a" show feat:docs/plan.md | grep -c 'src/w.sh')" = 2 ] && ! grep -q 'path=src/w.sh' "$wsam/progress.md"; then pass "the crash seam stops after the swap with the record in place"; else fail "crash after swap (rc=$rc rec=$rec)"; fi
out=$(run_state "$am_a" deps docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ]; then pass "deps --check honours an acceptance that only the amendment record holds"; else fail "record acceptance honoured (rc=$rc: $out)"; fi
# The base is the seven-character plan= token deps prints, as the skill text passes it.
base2b=$(run_state "$am_a" deps docs/plan.md 2>/dev/null | sed -n 's/^status=deps plan=\([0-9a-f]*\) .*/\1/p')
sed 's/^### Task 2: B$/### Task 2: B2/' "$TEST_ROOT/am.cand3" > "$TEST_ROOT/am.cand3b"
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand3b" --base "$base2b" --message "rename" 2>/dev/null); rc=$?
if [ "${#base2b}" = 7 ] && [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$(git -C "$am_a" show feat:docs/plan.md | grep -c 'Task 2: B2')" = 1 ]; then pass "a fresh amendment inside the crash window, from the seven-character plan= token, honours the surviving record's acceptance"; else fail "fresh amendment in the window (rc=$rc base=$base2b: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand3b" --base 0000000 2>/dev/null); rc=$?
if [ "$rc" -eq 14 ] && [ "${out%% current=*}" = "status=stale base=0000000" ]; then pass "a base no object matches is stale"; else fail "unknown base (rc=$rc: $out)"; fi
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand3" --base "$base2" --accept 'tasks=1,2 path=src/w.sh' --message "w twice" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out##* }" = "already=1" ] && grep -q '^scan: accepted-overlap tasks=1,2 path=src/w.sh$' "$wsam/progress.md" && grep -q ': w twice$' "$wsam/progress.md" && [ -z "$(ls -A "$wsam/amends" 2>/dev/null)" ]; then pass "the retry completes the ledger lines and removes the record"; else fail "retry completes (rc=$rc: $out)"; fi
# Refused under a held lease.
printf 'Task 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' >> "$wsam/progress.md"
run_state "$am_a" claim docs/plan.md final --session s1 >/dev/null
base3=$(git -C "$am_a" rev-parse feat:docs/plan.md)
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand3" --base "$base3" 2>/dev/null); rc=$?
if [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=lease:s1" ]; then pass "an amendment is refused while the branch lease is held"; else fail "amend under lease (rc=$rc: $out)"; fi
# Under a closing lease the refusal is branch-closing, before anything else.
lease_am=$(ls "$STATE_ROOT/$(state_key "$am_a").final-"* | head -n 1)
sed 's/^closing=.*/closing=1/' "$lease_am" > "$lease_am.new" && mv -f "$lease_am.new" "$lease_am"
out=$(run_state "$am_a" amend docs/plan.md --from "$TEST_ROOT/am.cand3" --base "$base3" 2>/dev/null); rc=$?
if [ "$rc" -eq 15 ] && [ "$out" = "status=branch-closing" ]; then pass "a closing lease refuses an amendment as branch-closing"; else fail "amend branch-closing (rc=$rc: $out)"; fi
run_state "$am_a" claim docs/plan.md final --session s1 --release >/dev/null
# A lost compare-and-swap: a writer moves the plan ref between the record and the swap. A moved head with the same plan is recomputed; one whose plan changed is stale, and neither leaves a record.
head3=$(git -C "$am_a" rev-parse feat)
adv_am=$(git -C "$am_a" commit-tree "$(git -C "$am_a" rev-parse "feat^{tree}")" -p "$head3" -m "advance" 2>/dev/null)
sed 's/^### Task 1: A$/### Task 1: A1/' "$TEST_ROOT/am.cand3" > "$TEST_ROOT/am.cand4"
out=$(cd "$am_a" && HYPERPOWERS_TEST_WRITER_AT="amend-before-swap:$adv_am" bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/am.cand4" --base "$base3" --accept 'tasks=1,2 path=src/x.sh' --message "a1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "${out%% *}" = "status=amended" ] && [ "$(git -C "$am_a" rev-parse "feat^")" = "$adv_am" ] && [ -z "$(ls -A "$wsam/amends" 2>/dev/null)" ]; then pass "a lost swap is recomputed on the moved head"; else fail "amend lost swap (rc=$rc: $out parent=$(git -C "$am_a" rev-parse "feat^" 2>/dev/null))"; fi
base4=$(git -C "$am_a" rev-parse feat:docs/plan.md)
sed 's/^### Task 2: B$/### Task 2: B3/' "$TEST_ROOT/am.cand4" > "$TEST_ROOT/am.cand5"
sed 's/^### Task 2: B$/### Task 2: B9/' "$TEST_ROOT/am.cand4" > "$TEST_ROOT/am.other"
other_blob=$(git -C "$am_a" hash-object -w "$TEST_ROOT/am.other")
other_tree=$(GIT_INDEX_FILE="$TEST_ROOT/am.index" sh -c 'git -C "$1" read-tree "$2" && git -C "$1" update-index --add --cacheinfo 100644,"$3",docs/plan.md && git -C "$1" write-tree' _ "$am_a" feat "$other_blob")
other_commit=$(git -C "$am_a" commit-tree "$other_tree" -p "$(git -C "$am_a" rev-parse feat)" -m "other amendment")
out=$(cd "$am_a" && HYPERPOWERS_TEST_WRITER_AT="amend-before-swap:$other_commit" bash "$SDD_STATE" amend docs/plan.md --from "$TEST_ROOT/am.cand5" --base "$base4" --accept 'tasks=1,2 path=src/x.sh' --message "b3" 2>/dev/null); rc=$?
if [ "$rc" -eq 14 ] && [ "${out%% current=*}" = "status=stale base=${base4:0:7}" ] && [ "$(git -C "$am_a" rev-parse feat)" = "$other_commit" ] && [ -z "$(ls -A "$wsam/amends" 2>/dev/null)" ]; then pass "a swap lost to a plan change is stale and leaves no record behind"; else fail "lost swap stale (rc=$rc: $out)"; fi
# An amendment record whose commit is not on the plan ref counts for nothing.
awk '{ print } /^- Modify: `src\/x.sh`$/ { print "- Modify: `src/z.sh`" }' "$TEST_ROOT/am.cand5" > "$TEST_ROOT/am.cand6"
dangling=$(git -C "$am_a" commit-tree "$(git -C "$am_a" rev-parse "feat^{tree}")" -p "$head3" -m dangling)
mkdir -p "$wsam/amends"; printf 'base=%s\nblob=%s\ncommit=%s\naccept=tasks=1,2 path=src/z.sh\n' "$base4" "$(git -C "$am_a" hash-object "$TEST_ROOT/am.cand6")" "$dangling" > "$wsam/amends/unpublished"
out=$(run_state "$am_a" deps --from "$TEST_ROOT/am.cand6" docs/plan.md --check 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qx 'conflict tasks=1,2 shares=src/z.sh'; then pass "an amendment record whose commit is not on the plan ref suppresses nothing"; else fail "unpublished record (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
rm -f "$wsam/amends/unpublished"
```

- [ ] **Step 2: Run the section to verify it fails**

Harness `~/.cache/hyperpowers/pd-amend-harness.sh`. Expected: every check `[FAIL]`.

- [ ] **Step 3: `cmd_amend`**

```bash
# --- amend -------------------------------------------------------------------
# The plan ref's only writer while a plan is open. The candidate is validated
# whole (graph and overlaps) before anything moves, the base blob must still
# be the authoritative one (so a concurrent amendment is never overwritten),
# and the acceptances are made durable in a record before the swap, so a
# crash between the swap and the ledger lines leaves nothing that reads an
# accepted overlap as undeclared.
cmd_amend() {
  local plan="" from="" base="" msg="" code="" accepts="" rel ref P cur blob graph out rc tree commit n record lease line integ sid a attempt full base_unknown="" errf
  while [ $# -gt 0 ]; do
    case "$1" in
      --from) [ $# -ge 2 ] || usage; from=$2; shift 2 ;;
      --base) [ $# -ge 2 ] || usage; base=$2; shift 2 ;;
      --accept) [ $# -ge 2 ] || usage; accepts="$accepts
$2"; shift 2 ;;
      --message) [ $# -ge 2 ] || usage; msg=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$from" ] && [ -n "$base" ] || usage
  [ -f "$from" ] || { echo "sdd-state: no such file: $from" >&2; echo "status=error"; return 2; }
  resolve_plan "$plan"
  hp_git_version_at_least 2 38 || { echo "sdd-state: git 2.38 or newer is required to amend the plan ref (found $(git --version))" >&2; echo "status=error"; return 2; }
  # amend writes only the plan ref, so it holds the plan repository's lock; the
  # code repository (--code-repo, or the cwd's) is checked, not locked.
  code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  rel=$(hp_plan_rel "$PLAN"); sid=$(hp_session_id); [ -n "$sid" ] || sid=unknown
  [ -n "$msg" ] || msg="amendment"
  blob=$(git -C "$REPO" hash-object "$from")
  # --base is the plan= token deps prints, seven characters: resolve it to the
  # full blob id. An abbreviation that matches nothing is a base that is not
  # current, so it reads as stale below; an ambiguous one cannot be compared.
  errf="${TMPDIR:-/tmp}/sdd-amend-base.$$"
  if full=$(git -C "$REPO" rev-parse --verify "$base^{blob}" 2>"$errf"); then base=$full
  elif grep -q ambiguous "$errf"; then rm -f "$errf"; echo "sdd-state: $base is ambiguous; pass the full blob id (git -C $REPO rev-parse <plan ref>:$rel)" >&2; echo "status=error"; return 2
  else base_unknown=1; fi
  rm -f "$errf"
  graph=$(hp_plan_graph "$from") || { echo "status=invalid plan=${blob:0:7}"; return 2; }
  line=$(plan_line_of "$WSDIR/progress.md")
  ref=$(plan_ref_of_ledger "$WSDIR/progress.md"); [ -n "$ref" ] || ref=$(git -C "$REPO" branch --show-current)
  [ -n "$ref" ] || { echo "status=detached-head repo=plan"; return 11; }
  hp_lock "$PLAN_DIR" || return 2
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  if [ -n "$line" ]; then
    integ=$(plan_field "$line" integration); lease=$(hp_lease_key "$PLAN_DIR" "$integ")
    if [ -f "$lease" ] && [ "$(sed -n 's/^closing=//p' "$lease")" = 1 ]; then hp_unlock; echo "status=branch-closing"; return 15; fi
    if [ -f "$lease" ]; then hp_unlock; echo "status=checked-out worktree=lease:$(sed -n 's/^session=//p' "$lease")"; return 13; fi
  fi
  mkdir -p "$WSDIR/amends" || { hp_unlock; echo "status=error"; return 2; }
  record="$WSDIR/amends/$blob"
  # A retry after a crash past the swap: the record names a published commit.
  if [ -f "$record" ] && commit=$(sed -n 's/^commit=//p' "$record") && [ -n "$commit" ] && git -C "$REPO" merge-base --is-ancestor "$commit" "refs/heads/$ref" 2>/dev/null; then
    amend_bookkeeping; hp_unlock; echo "status=amended head=${commit:0:7} plan=${blob:0:7} already=1"; return 0
  fi
  out=$(hp_plan_overlaps "$from" "$WSDIR/progress.md" "$WSDIR/amends" "$REPO" "$ref" | grep -v -F -f <(printf '%s\n' "$accepts" | sed '/^$/d' | sed 's/^tasks=\([0-9,]*\) path=\(.*\)$/conflict tasks=\1 shares=\2/; s/^tasks=\([0-9,]*\) interface=\(.*\)$/conflict tasks=\1 interface=\2 direction=consumer-first/') ); rc=$?
  if [ -n "$out" ]; then hp_unlock; n=$(printf '%s\n' "$out" | grep -c .); echo "status=conflicts plan=${blob:0:7} count=$n"; printf '%s\n' "$out"; return 1; fi
  for attempt in 1 2 3; do
    P=$(git -C "$REPO" rev-parse -q --verify "refs/heads/$ref^{commit}") || { hp_unlock; echo "status=error"; return 2; }
    cur=$(git -C "$REPO" rev-parse -q --verify "$P:$rel" 2>/dev/null) || cur=""
    # Stale leaves no record behind: one a lost attempt wrote would otherwise
    # be read as an acceptance once its commit is nowhere.
    { [ -z "$base_unknown" ] && [ "$cur" = "$base" ]; } || { rm -f "$record"; hp_unlock; echo "status=stale base=${base:0:7} current=${cur:0:7}"; return 14; }
    tree=$(GIT_INDEX_FILE="$WSDIR/amends/.index-$$" sh -c 'git -C "$1" read-tree "$2" && git -C "$1" update-index --add --cacheinfo 100644,"$3","$4" && git -C "$1" write-tree' _ "$REPO" "$P" "$(git -C "$REPO" hash-object -w "$from")" "$rel") || { rm -f "$WSDIR/amends/.index-$$"; hp_unlock; echo "status=error"; return 2; }
    rm -f "$WSDIR/amends/.index-$$"
    commit=$(printf 'docs(hyperpowers): amend %s: %s\n' "$(basename "$PLAN")" "$msg" | hp_git_id "$REPO" commit-tree "$tree" -p "$P") || { hp_unlock; echo "status=error"; return 2; }
    { printf 'base=%s\nblob=%s\ncommit=%s\n' "$base" "$blob" "$commit"; printf '%s\n' "$accepts" | sed '/^$/d; s/^/accept=/'; } > "$record.new" && mv -f "$record.new" "$record" || { hp_unlock; echo "status=error"; return 2; }
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in amend-before-swap:*) git -C "$REPO" update-ref "refs/heads/$ref" "${HYPERPOWERS_TEST_WRITER_AT#amend-before-swap:}" 2>/dev/null; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
    if git -C "$REPO" update-ref -m "sdd amend" "refs/heads/$ref" "$commit" "$P" 2>/dev/null; then
      if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = amend-after-swap ]; then hp_unlock; exit 99; fi
      amend_bookkeeping; hp_unlock; echo "status=amended head=${commit:0:7} plan=${blob:0:7}"; return 0
    fi
  done
  rm -f "$record"
  hp_unlock; echo "sdd-state: the plan ref moved three times during the amendment (last seen ${P:0:7})" >&2; echo "status=error"; return 2
}
# The ledger lines an amendment owes, each appended once, then the record goes.
amend_bookkeeping() {
  local a
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    grep -qxF "scan: accepted-overlap $a" "$WSDIR/progress.md" || printf 'scan: accepted-overlap %s\n' "$a" >> "$WSDIR/progress.md"
  done < <(sed -n 's/^accept=//p' "$record")
  grep -q "^plan: amended ${blob:0:7} by " "$WSDIR/progress.md" || printf 'plan: amended %s by %s: %s\n' "${blob:0:7}" "$sid" "$msg" >> "$WSDIR/progress.md"
  rm -f "$record"
}
```

`amend_bookkeeping` reads `record`, `blob`, `sid`, `msg` and `WSDIR` from `cmd_amend`'s scope (they are `local` there and visible to a function it calls). Usage line: `amend PLAN_FILE --from FILE --base BLOB [--accept SPEC ...] [--message SUBJECT] [--code-repo DIR]`; dispatch `amend) cmd_amend "$@" ;;`. The `--accept` normalization keeps `path=` and `interface=` spellings exactly as `hp_plan_overlaps` prints the ledger key, so the ledger line and the suppression match.

- [ ] **Step 4: Run the section to verify it passes**

Run the harness. Expected: every `amend` check `[PASS]`; the `deps` section still passes (its `--check` now also reads `plans/<ws>/amends/`).

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): amend validates a candidate plan whole and publishes it on the plan ref by compare-and-swap"
```

### Task 7: `merge-back`

**Risk tier:** high — the integration ref's writer, with a merge record, idempotent recovery and three crash boundaries.

**Depends on:** Task 6


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_merge_back`, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `merge-back`)

**Interfaces:**
- Consumes: `plan_line_of`, `plan_field`, `ws8_of`, `code_repo_arg`, `hp_lock_pair`, `hp_lease_key`, `authoritative_plan_blob`, `hp_plan_graph`, `hp_git_id`, `hp_git_version_at_least`. The approval line `Task <N>: approved <sha7>` is defined here as the line this command reads; the controller writes it, and Task 11's skill text says when.
- Produces: `sdd-state merge-back PLAN_FILE N --session SID --commit SHA [--code-repo DIR]`: `status=merged task=<N> head=<sha7>` (exit 0; `already=1` on a recovered retry); `status=not-holder owner=<sid>` (exit 4); `status=not-approved approved=<sha7|none>` (exit 12); `status=blocked waiting=<list>` (exit 7); `status=checked-out worktree=<path>|lease:<sid>` (exit 13); `status=conflict task=<N> paths=<list>` (exit 8) with a `merge` waiting record; `status=error` naming both heads after three lost swaps or the git floor. The merge record `plans/<ws>/merges/task-<N>` holds `approved=`, `proposed=`, `base=`. Ledger line `Task <N>: merged <sha7> into <integration> (from <sha7>)`. Crash seams `merge-back-after-record`, `merge-back-after-swap`, `merge-back-after-ledger`; writer seam `merge-back-before-swap:<sha>`. The controller's detach and branch deletion are skill text (Task 11), not this command.

**Mirror:** the merge plumbing in `cmd_sync` (`sdd-state:1822-1838`); `hp_commit_paths`' compare-and-swap loop.

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "merge-back: the integration ref's writer"
make_pair mb; mb_a=$PAIR_A
mkdir -p "$mb_a/docs" "$mb_a/src"; : > "$mb_a/docs/spec.md"; printf 'base\n' > "$mb_a/src/a.txt"; printf 'base\n' > "$mb_a/src/b.txt"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 2: B\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 3: C\n\n**Risk tier:** standard\n\n**Depends on:** Task 1\n' > "$mb_a/docs/plan.md"
git -C "$mb_a" add .; git -C "$mb_a" commit -qm base; git -C "$mb_a" push -q origin main 2>/dev/null; git -C "$mb_a" switch -q -c feat
run_state "$mb_a" sync docs/plan.md >/dev/null 2>&1; wsmb=$(run_sdd_dir "$mb_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsmb/progress.md"; run_state "$mb_a" register docs/plan.md --session s1 --integration feat >/dev/null
ws8mb=$(basename "$wsmb" | sed 's/.*-//')
make_repo "$TEST_ROOT/foreign-mb"
run_state "$mb_a" claim docs/plan.md 1 --session s1 >/dev/null; run_state "$mb_a" claim docs/plan.md 2 --session s2 >/dev/null
# Session 1 works task 1 on its branch (fast-forward case).
git -C "$mb_a" switch -q "feat.$ws8mb.task-1"; printf 'one\n' > "$mb_a/src/a.txt"; git -C "$mb_a" commit -qam "task 1"; t1=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=none" ]; then pass "merge-back refuses a commit no approval line names"; else fail "not-approved (rc=$rc: $out)"; fi
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" --code-repo "$TEST_ROOT/foreign-mb" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "merge-back refuses a foreign --code-repo"; else fail "merge-back wrong-repo (rc=$rc: $out)"; fi
printf 'Task 1: approved %s\n' "${t1:0:7}" >> "$wsmb/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s2 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 4 ] && [ "$out" = "status=not-holder owner=s1" ]; then pass "merge-back refuses a session that does not hold the claim"; else fail "not-holder (rc=$rc: $out)"; fi
git -C "$mb_a" switch -q feat
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 13 ] && [ "${out%% worktree=*}" = "status=checked-out" ]; then pass "merge-back refuses while the integration branch is checked out"; else fail "checked-out (rc=$rc: $out)"; fi
git -C "$mb_a" switch -q --detach feat
lease_mb="$STATE_ROOT/$(state_key "$mb_a").final-$(printf 'refs/heads/feat' | git -C "$mb_a" hash-object --stdin | cut -c1-12)"
printf 'session=s9\nhost=h\nplan=other\nbranch=feat\ntime=2026-01-01T00:00:00Z\nclosing=0\n' > "$lease_mb"
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 13 ] && [ "$out" = "status=checked-out worktree=lease:s9" ]; then pass "merge-back refuses while a final train holds the branch lease"; else fail "merge-back under lease (rc=$rc: $out)"; fi
rm -f "$lease_mb"
printf '2026-01-01T00:00:00Z\n' > "$wsmb/activity/s1"
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=1 head=${t1:0:7}" ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$t1" ] && grep -q "^Task 1: merged ${t1:0:7} into feat (from ${t1:0:7})$" "$wsmb/progress.md" && [ "$(sed -n 's/^proposed=//p' "$wsmb/merges/task-1")" = "$t1" ] && [ "$(cat "$wsmb/activity/s1")" != "2026-01-01T00:00:00Z" ]; then pass "a fast-forward merge-back moves the ref to the approved commit, records it and stamps activity"; else fail "fast-forward (rc=$rc: $out)"; fi
out=$(run_state "$mb_a" merge-back docs/plan.md 1 --session s1 --commit "$t1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=1 head=${t1:0:7} already=1" ] && [ "$(grep -c '^Task 1: merged' "$wsmb/progress.md")" = 1 ]; then pass "a repeated merge-back is idempotent"; else fail "already (rc=$rc: $out)"; fi
# Session 2's task 2 branched before task 1 merged: a merge commit.
git -C "$mb_a" switch -q "feat.$ws8mb.task-2"; printf 'two\n' > "$mb_a/src/b.txt"; git -C "$mb_a" commit -qam "task 2"; t2=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 2: approved %s\n' "${t2:0:7}" >> "$wsmb/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan.md 2 --session s2 --commit "$t2" 2>/dev/null); rc=$?
hm=$(git -C "$mb_a" rev-parse feat)
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=2 head=${hm:0:7}" ] && [ "$(git -C "$mb_a" rev-parse "$hm^1")" = "$t1" ] && [ "$(git -C "$mb_a" rev-parse "$hm^2")" = "$t2" ] && [ "$(git -C "$mb_a" log -1 --format=%s "$hm")" = "Merge task 2: B" ] && [ "$(git -C "$mb_a" show feat:src/a.txt)" = one ] && [ "$(git -C "$mb_a" show feat:src/b.txt)" = two ]; then pass "a divergent merge-back makes one merge commit titled with the task"; else fail "merge commit (rc=$rc: $out)"; fi
# A dependent whose predecessor is not complete is blocked even when approved.
run_state "$mb_a" claim docs/plan.md 3 --session s1 >/dev/null 2>&1
printf 'Task 1: complete (commits 1111111..%s, review clean)\n' "${t1:0:7}" >> "$wsmb/progress.md"
run_state "$mb_a" claim docs/plan.md 3 --session s1 >/dev/null
git -C "$mb_a" switch -q "feat.$ws8mb.task-3"; printf 'three\n' > "$mb_a/src/a.txt"; git -C "$mb_a" commit -qam "task 3"; t3=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 3: approved %s\n' "${t3:0:7}" >> "$wsmb/progress.md"
sed -i '' 's/^Task 1: complete .*$/Task 1: pending/' "$wsmb/progress.md" 2>/dev/null || sed -i 's/^Task 1: complete .*$/Task 1: pending/' "$wsmb/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan.md 3 --session s1 --commit "$t3" 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "$out" = "status=blocked waiting=1" ]; then pass "merge-back rechecks the predecessors against the authoritative graph"; else fail "blocked at merge-back (rc=$rc: $out)"; fi
sed -i '' "s/^Task 1: pending$/Task 1: complete (commits 1111111..${t1:0:7}, review clean)/" "$wsmb/progress.md" 2>/dev/null || sed -i "s/^Task 1: pending$/Task 1: complete (commits 1111111..${t1:0:7}, review clean)/" "$wsmb/progress.md"
# A conflict: a commit on the integration branch touches a.txt after task 3 branched and task 3 also edits it.
git -C "$mb_a" switch -q feat; printf 'other\n' > "$mb_a/src/a.txt"; git -C "$mb_a" commit -qam "stranger edit"; git -C "$mb_a" switch -q --detach feat
out=$(run_state "$mb_a" merge-back docs/plan.md 3 --session s1 --commit "$t3" 2>/dev/null); rc=$?
if [ "$rc" -eq 8 ] && [ "$out" = "status=conflict task=3 paths=src/a.txt" ] && [ "$(git -C "$mb_a" log -1 --format=%s feat)" = "stranger edit" ] && [ "$(sed -n 's/^kind=//p' "$wsmb/waiting/s1")" = merge ]; then pass "a conflict moves no ref and posts a merge waiting record"; else fail "conflict (rc=$rc: $out)"; fi
# Resolve on the task branch, re-approve, retry: the record is cleared.
git -C "$mb_a" switch -q "feat.$ws8mb.task-3"; git -C "$mb_a" merge -q feat >/dev/null 2>&1; printf 'three\n' > "$mb_a/src/a.txt"; git -C "$mb_a" commit -qam "resolve" ; t3b=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 3: approved %s\n' "${t3b:0:7}" >> "$wsmb/progress.md"
out=$(run_state "$mb_a" merge-back docs/plan.md 3 --session s1 --commit "$t3" 2>/dev/null); rc=$?
if [ "$rc" -eq 12 ] && [ "$out" = "status=not-approved approved=${t3b:0:7}" ]; then pass "only the newest approved commit may merge"; else fail "newest approved (rc=$rc: $out)"; fi
out=$(run_state "$mb_a" merge-back docs/plan.md 3 --session s1 --commit "$t3b" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$wsmb/waiting/s1" ] && [ "$(git -C "$mb_a" show feat:src/a.txt)" = three ]; then pass "the retry after resolution merges and clears the waiting record"; else fail "resolved merge (rc=$rc: $out)"; fi
# Crash seams: after the record (nothing published), after the swap (bookkeeping on retry, after another task advanced), after the ledger line.
run_state "$mb_a" claim docs/plan.md 2 --session s2 >/dev/null 2>&1
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: X\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 2: Y\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$mb_a/docs/plan2.md"
git -C "$mb_a" switch -q feat; git -C "$mb_a" add docs; git -C "$mb_a" commit -qm plan2; git -C "$mb_a" switch -q --detach feat
wsmb2=$(run_sdd_dir "$mb_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsmb2/progress.md"; run_state "$mb_a" register docs/plan2.md --session s3 --integration feat >/dev/null
ws8mb2=$(printf '%s' "$(basename "$wsmb2")" | sed 's/.*-//')
run_state "$mb_a" claim docs/plan2.md 1 --session s3 >/dev/null; run_state "$mb_a" claim docs/plan2.md 2 --session s3 >/dev/null
git -C "$mb_a" switch -q "feat.$ws8mb2.task-1"; printf 'x\n' > "$mb_a/src/x.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm x; x1=$(git -C "$mb_a" rev-parse HEAD)
git -C "$mb_a" switch -q "feat.$ws8mb2.task-2"; printf 'y\n' > "$mb_a/src/y.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm y; y1=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 1: approved %s\nTask 2: approved %s\n' "${x1:0:7}" "${y1:0:7}" >> "$wsmb2/progress.md"
hbefore=$(git -C "$mb_a" rev-parse feat)
( cd "$mb_a" && HYPERPOWERS_TEST_CRASH_AT=merge-back-after-record bash "$SDD_STATE" merge-back docs/plan2.md 1 --session s3 --commit "$x1" >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 99 ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$hbefore" ] && [ -f "$wsmb2/merges/task-1" ]; then pass "a crash after the record publishes nothing"; else fail "crash after record (rc=$rc)"; fi
( cd "$mb_a" && HYPERPOWERS_TEST_CRASH_AT=merge-back-after-swap bash "$SDD_STATE" merge-back docs/plan2.md 1 --session s3 --commit "$x1" >/dev/null 2>&1 ); rc=$?
pub=$(sed -n 's/^proposed=//p' "$wsmb2/merges/task-1")
if [ "$rc" -eq 99 ] && [ "$(git -C "$mb_a" rev-parse feat)" = "$pub" ] && ! grep -q '^Task 1: merged' "$wsmb2/progress.md"; then pass "a crash after the swap leaves the ref moved and the ledger line owed"; else fail "crash after swap (rc=$rc)"; fi
out=$(run_state "$mb_a" merge-back docs/plan2.md 2 --session s3 --commit "$y1" 2>/dev/null); rc=$?
out=$(run_state "$mb_a" merge-back docs/plan2.md 1 --session s3 --commit "$x1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=merged task=1 head=${pub:0:7} already=1" ] && grep -q "^Task 1: merged ${pub:0:7} into feat" "$wsmb2/progress.md"; then pass "the retry names the record's commit after another task advanced the head"; else fail "retry after advance (rc=$rc: $out)"; fi
( cd "$mb_a" && HYPERPOWERS_TEST_CRASH_AT=merge-back-after-ledger bash "$SDD_STATE" merge-back docs/plan2.md 1 --session s3 --commit "$x1" >/dev/null 2>&1 ); rc=$?
out=$(run_state "$mb_a" merge-back docs/plan2.md 1 --session s3 --commit "$x1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c '^Task 1: merged' "$wsmb2/progress.md")" = 1 ]; then pass "a retry after the ledger line appends nothing twice"; else fail "retry after ledger (rc=$rc: $out)"; fi
# The lost compare-and-swap: a writer seam moves the integration ref between the merge record and the swap; the command recomputes against the moved head.
```

Continue the fixture:

```bash
printf '### Task 5: V\n\n**Risk tier:** standard\n\n**Depends on:** none\n' >> "$mb_a/docs/plan2.md"; git -C "$mb_a" switch -q feat; git -C "$mb_a" commit -qam "plan2 task 5"; git -C "$mb_a" switch -q --detach feat
run_state "$mb_a" claim docs/plan2.md 5 --session s3 >/dev/null; git -C "$mb_a" switch -q "feat.$ws8mb2.task-5"; printf 'v\n' > "$mb_a/src/v.txt"; git -C "$mb_a" add src; git -C "$mb_a" commit -qm v; v1=$(git -C "$mb_a" rev-parse HEAD); git -C "$mb_a" switch -q --detach feat
printf 'Task 5: approved %s\n' "${v1:0:7}" >> "$wsmb2/progress.md"
adv2=$(git -C "$mb_a" commit-tree "$(git -C "$mb_a" rev-parse feat^{tree})" -p "$(git -C "$mb_a" rev-parse feat)" -m "advance" 2>/dev/null)
out=$(cd "$mb_a" && HYPERPOWERS_TEST_WRITER_AT="merge-back-before-swap:$adv2" bash "$SDD_STATE" merge-back docs/plan2.md 5 --session s3 --commit "$v1" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(sed -n 's/^base=//p' "$wsmb2/merges/task-5")" = "$adv2" ] && [ "$(git -C "$mb_a" rev-parse feat^1)" = "$adv2" ]; then pass "a lost swap is recomputed against the moved head"; else fail "lost swap recomputed (rc=$rc: $out base=$(sed -n 's/^base=//p' "$wsmb2/merges/task-5" 2>/dev/null))"; fi
```


- [ ] **Step 2: Run the section to verify it fails**

Harness `~/.cache/hyperpowers/pd-merge-harness.sh`. Expected: every check `[FAIL]`.

- [ ] **Step 3: `cmd_merge_back`**

```bash
# --- merge-back --------------------------------------------------------------
# Merges exactly the commit the reviewers approved into the integration branch,
# under both repositories' locks, by the plumbing sync uses for the state
# branch. The merge record is written before the swap and names the published
# commit after it, so a retry after any crash recognizes its state: nothing
# before the record, a record without its commit on the ref before the swap,
# and bookkeeping only after it. The controller's detach and branch deletion
# follow this command and are its own idempotent steps.
cmd_merge_back() {
  local plan="" n="" sid="" sha="" code="" line integ ref record H approved mt tree new paths attempt published pair tmp graph deps d waiting lease owner wt
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --commit) [ $# -ge 2 ] || usage; sha=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) if [ -z "$plan" ]; then plan=$1; elif [ -z "$n" ]; then n=$1; else usage; fi; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$n" ] && [ -n "$sid" ] && [ -n "$sha" ] || usage
  case "$n" in ''|*[!0-9]*) usage ;; esac
  resolve_plan "$plan"
  hp_git_version_at_least 2 38 || { echo "sdd-state: git 2.38 or newer is required to merge a task back (found $(git --version))" >&2; echo "status=error"; return 2; }
  code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  line=$(plan_line_of "$WSDIR/progress.md"); [ -n "$line" ] || { echo "sdd-state: no plan line; register the plan first" >&2; echo "status=error"; return 2; }
  integ=$(plan_field "$line" integration); ref="refs/heads/$integ"
  sha=$(git -C "$code" rev-parse -q --verify "$sha^{commit}" 2>/dev/null) || { echo "sdd-state: no such commit in $code: $sha" >&2; echo "status=error"; return 2; }
  hp_lock_pair "$PLAN_DIR" "$code" || return 2
  recover_apply || { hp_unlock; echo "status=error"; return 2; }
  owner=$(sed -n 's/^session=//p' "$WSDIR/claims/task-$n/owner" 2>/dev/null)
  [ "$owner" = "$sid" ] || { hp_unlock; echo "status=not-holder owner=${owner:-none}"; return 4; }
  approved=$(grep -E "^Task $n: approved [0-9a-f]{7}" "$WSDIR/progress.md" | tail -n 1 | sed 's/.*approved //')
  [ "${sha:0:7}" = "$approved" ] || { hp_unlock; echo "status=not-approved approved=${approved:-none}"; return 12; }
  pair=$(authoritative_plan_blob) || { hp_unlock; echo "status=error"; return 2; }
  tmp=${pair#* }; graph=$(hp_plan_graph "$tmp"); rc=$?; rm -f "$tmp"
  [ "$rc" -eq 0 ] || { hp_unlock; echo "status=invalid"; return 2; }
  deps=$(printf '%s\n' "$graph" | sed -n "s/^task=$n depends=//p"); waiting=""
  if [ -n "$deps" ] && [ "$deps" != none ]; then for d in $(printf '%s' "$deps" | tr ',' ' '); do grep -Eq "(^|[^A-Za-z0-9])Task $d: complete" "$WSDIR/progress.md" || waiting="$waiting,$d"; done; fi
  [ -z "$waiting" ] || { hp_unlock; echo "status=blocked waiting=${waiting#,}"; return 7; }
  lease=$(hp_lease_key "$PLAN_DIR" "$integ")
  if [ -f "$lease" ]; then hp_unlock; echo "status=checked-out worktree=lease:$(sed -n 's/^session=//p' "$lease")"; return 13; fi
  wt=$(git -C "$code" worktree list --porcelain | awk -v b="$ref" '/^worktree /{w=$2} $0 == "branch " b {print w; exit}')
  [ -z "$wt" ] || { hp_unlock; echo "status=checked-out worktree=$(enc "$wt")"; return 13; }
  mkdir -p "$WSDIR/merges" || { hp_unlock; echo "status=error"; return 2; }
  record="$WSDIR/merges/task-$n"
  for attempt in 1 2 3; do
    H=$(git -C "$code" rev-parse -q --verify "$ref^{commit}") || { hp_unlock; echo "status=error"; return 2; }
    if git -C "$code" merge-base --is-ancestor "$sha" "$H" 2>/dev/null; then
      published=$(sed -n 's/^proposed=//p' "$record" 2>/dev/null)
      if [ -z "$published" ]; then
        if git -C "$code" rev-list --first-parent "$H" | grep -qx "$sha"; then published=$sha; else published=$(git -C "$code" rev-list --first-parent --parents "$H" | awk -v s="$sha" '$3 == s {print $1; exit}'); fi
      fi
      merge_back_bookkeeping; hp_unlock; echo "status=merged task=$n head=${published:0:7} already=1"; return 0
    fi
    if git -C "$code" merge-base --is-ancestor "$H" "$sha" 2>/dev/null; then
      new=$sha
    else
      if ! mt=$(git -C "$code" merge-tree --write-tree "$H" "$sha" 2>/dev/null); then
        # --name-only prints the tree id, the conflicted paths one per line, a
        # blank line and then informational messages; the paths are the lines
        # between the first and the blank.
        paths=$(git -C "$code" merge-tree --write-tree --name-only "$H" "$sha" 2>/dev/null | awk 'NR == 1 { next } /^$/ { exit } { print }' | paste -sd, -)
        mkdir -p "$WSDIR/waiting"; printf 'session=%s\ntask=%s\nkind=merge\nsince=%s\nnote=%s\nworktree=%s\nbranch=%s\nhost=%s\n' "$sid" "$n" "$(hp_utc_now)" "conflict in $paths" "$(pwd -P)" "$(git branch --show-current 2>/dev/null)" "$(hostname)" > "$WSDIR/waiting/$sid.new" && mv -f "$WSDIR/waiting/$sid.new" "$WSDIR/waiting/$sid"
        hp_unlock; echo "status=conflict task=$n paths=$paths"; return 8
      fi
      tree=$(printf '%s\n' "$mt" | head -n 1)
      new=$(printf 'Merge task %s: %s\n' "$n" "$(sed -n "s/^### Task $n: //p" "$PLAN" | head -n 1)" | hp_git_id "$code" commit-tree "$tree" -p "$H" -p "$sha") || { hp_unlock; echo "status=error"; return 2; }
    fi
    printf 'approved=%s\nproposed=%s\nbase=%s\n' "$sha" "$new" "$H" > "$record.new" && mv -f "$record.new" "$record" || { hp_unlock; echo "status=error"; return 2; }
    if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = merge-back-after-record ]; then hp_unlock; exit 99; fi
    case "${HYPERPOWERS_TEST_WRITER_AT:-}" in merge-back-before-swap:*) git -C "$code" update-ref "$ref" "${HYPERPOWERS_TEST_WRITER_AT#merge-back-before-swap:}" 2>/dev/null; HYPERPOWERS_TEST_WRITER_AT="" ;; esac
    if git -C "$code" update-ref -m "sdd merge-back task $n" "$ref" "$new" "$H" 2>/dev/null; then
      if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = merge-back-after-swap ]; then hp_unlock; exit 99; fi
      published=$new; merge_back_bookkeeping; hp_unlock; echo "status=merged task=$n head=${new:0:7}"; return 0
    fi
  done
  hp_unlock; echo "sdd-state: the integration branch moved three times during the merge-back (last seen ${H:0:7})" >&2; echo "status=error"; return 2
}
# The ledger line, the cleared waiting record and the activity stamp, each
# idempotent, using the published commit.
merge_back_bookkeeping() {
  grep -q "^Task $n: merged ${published:0:7} into $integ" "$WSDIR/progress.md" || printf 'Task %s: merged %s into %s (from %s)\n' "$n" "${published:0:7}" "$integ" "${sha:0:7}" >> "$WSDIR/progress.md"
  if [ "${HYPERPOWERS_TEST_CRASH_AT:-}" = merge-back-after-ledger ]; then hp_unlock; exit 99; fi
  if [ -f "$WSDIR/waiting/$sid" ] && [ "$(sed -n 's/^kind=//p' "$WSDIR/waiting/$sid")" = merge ]; then rm -f "$WSDIR/waiting/$sid"; fi
  write_activity "$sid"
}
```

`git merge-tree --write-tree --name-only` prints the tree id, the conflicted paths, a blank line and then informational messages; on a conflict the plain call exits 1 and the second call lists the paths, read up to the blank line. `merge_back_bookkeeping` reads `n`, `published`, `integ`, `sha`, `sid`, `WSDIR` from the caller. Usage line: `merge-back PLAN_FILE N --session SID --commit SHA [--code-repo DIR]`; dispatch `merge-back) cmd_merge_back "$@" ;;`.

- [ ] **Step 4: Run the section to verify it passes**

Run the harness. Expected: every `merge-back` check `[PASS]`.

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): merge-back publishes the approved commit on the integration branch with a merge record and idempotent recovery"
```

### Task 8: `wait`, `activity`, `snapshot --session` and the board

**Risk tier:** high — durable per-session records (`waiting/`, `activity/`) and the reader your human partner acts on.

**Depends on:** Task 7


**Files:**
- Modify: `skills/subagent-driven-development/scripts/sdd-common.sh` (`hp_utc_epoch`, after `hp_utc_now` at `:115`)
- Modify: `skills/subagent-driven-development/scripts/sdd-state` (`cmd_wait`, `cmd_board`, `cmd_snapshot --session`, `write_activity`, usage, dispatch)
- Test: `tests/sdd/test-sdd-state.sh` (section `board`)

**Interfaces:**
- Consumes: `cmd_sync` (invoked as a subprocess for the board's fetch), `next_classify` (Task 4, called in-process for the frontier), `plan_line_of`, `open_claims`, `hp_has_remote`.
- Produces: `hp_utc_epoch <YYYY-MM-DDTHH:MM:SSZ>` prints seconds since the epoch on GNU and BSD `date`. `claim`, `merge-back`, `wait` and `snapshot --session SID` call `write_activity` (Task 3). `sdd-state wait PLAN_FILE --session SID --kind (question|tasks|merge|gate|handoff) [--task N|final] --note "<one line>"`: `status=waiting kind=<kind>`; `--clear`: `status=cleared`; a note with a newline, an unknown kind, or a missing note: `status=error` (exit 2). `sdd-state board PLAN_FILE [--code-repo DIR]`: first line `status=board sync=<status> sessions=<n> waiting=<m> frontier=<list|none>`, then one `session <sid> task=<N|final|none> since=<UTC|none> worktree=<p> branch=<b> host=<h|unknown> waiting=<kind|none> waiting-since=<UTC|none> note=<enc text|none> silence=<seconds|none> quiet-since=<UTC|none>` per session (`host=` from the session's claim or waiting record, `silence=` the age of its activity file), then `held task=<N> owner=<sid> since=<UTC>` lines, then `leftover branch=<ref>` lines, then `sibling plan=<ws> spec=<p> integration=<b>` lines; exit 0 whatever `sync` returned, a non-success `sync`'s stderr line repeated once on stderr. `board --repo DIR` prints `status=board plans=<n>` then, per open workspace, `plan ws=<ws> spec=<p> integration=<b> sessions=<n> waiting=<m> held=<list>` grouped by spec then branch, then one `lease branch=<b> session=<sid> plan=<ws> closing=<0|1>` line per lease file in the state root. `board PLAN_FILE` validates `--code-repo`, or the cwd's repository when the cwd is one, through `code_repo_arg` with the ledger before any output (`status=wrong-repo`, exit 9); with neither it prints no `leftover` lines. `quiet-since` is set when the session holds a claim, has no waiting record, and its activity file is older than 1800 seconds (or missing).

- [ ] **Step 1: Write the failing fixtures**

```bash
echo "board: waiting records, activity and the board"
make_pair bd; bd_a=$PAIR_A; bd_b=$PAIR_B
mkdir -p "$bd_a/docs"; : > "$bd_a/docs/spec.md"
printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n\n### Task 2: B\n\n**Risk tier:** standard\n\n**Depends on:** Task 1\n' > "$bd_a/docs/plan.md"
git -C "$bd_a" add docs; git -C "$bd_a" commit -qm plan; git -C "$bd_a" push -q origin main 2>/dev/null; git -C "$bd_a" switch -q -c feat; git -C "$bd_a" push -q -u origin feat 2>/dev/null
run_state "$bd_a" sync docs/plan.md >/dev/null 2>&1; wsbd=$(run_sdd_dir "$bd_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsbd/progress.md"; run_state "$bd_a" register docs/plan.md --session s1 --integration feat >/dev/null
make_repo "$TEST_ROOT/foreign-bd"
out=$(run_state "$bd_a" board docs/plan.md --code-repo "$TEST_ROOT/foreign-bd" 2>/dev/null); rc=$?
if [ "$rc" -eq 9 ] && [ "${out%% expected=*}" = "status=wrong-repo" ]; then pass "board refuses a foreign --code-repo"; else fail "board wrong-repo (rc=$rc: $out)"; fi
out=$(cd "$TEST_ROOT" && bash "$SDD_STATE" board "$bd_a/docs/plan.md" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | sed -n 1p | grep -q ' frontier=1$' && ! printf '%s\n' "$out" | grep -q '^leftover '; then pass "a board run outside any repository still computes the frontier and prints no leftovers"; else fail "board outside a repository (rc=$rc: $(sed -n 1p <<<"$out"))"; fi
out=$(run_state "$bd_a" wait docs/plan.md --session s1 --kind question --task 1 --note "which parser?" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=waiting kind=question" ] && [ "$(sed -n 's/^note=//p' "$wsbd/waiting/s1")" = "which parser?" ] && [ -f "$wsbd/activity/s1" ]; then pass "wait writes the record and the activity stamp"; else fail "wait writes (rc=$rc: $out)"; fi
out=$(run_state "$bd_a" wait docs/plan.md --session s1 --kind tasks --note "held: 1@s2" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(sed -n 's/^kind=//p' "$wsbd/waiting/s1")" = tasks ]; then pass "a second wait replaces the record"; else fail "wait replaces (rc=$rc: $out)"; fi
out=$(run_state "$bd_a" wait docs/plan.md --session s1 --kind question --note "$(printf 'two\nlines')" 2>/dev/null); rc=$?
if [ "$rc" -eq 2 ] && [ "$out" = "status=error" ] && [ "$(sed -n 's/^kind=//p' "$wsbd/waiting/s1")" = tasks ]; then pass "a note with a newline is refused and the record kept"; else fail "newline refused (rc=$rc: $out)"; fi
out=$(run_state "$bd_a" wait docs/plan.md --session s1 --clear 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=cleared" ] && [ ! -f "$wsbd/waiting/s1" ]; then pass "clear removes the record"; else fail "clear (rc=$rc: $out)"; fi
out=$(run_state "$bd_a" wait docs/plan.md --session s1 --clear 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "status=cleared" ]; then pass "clearing nothing is cleared"; else fail "clear nothing (rc=$rc: $out)"; fi
# Records travel with snapshot and appear after sync on the other host.
run_state "$bd_a" wait docs/plan.md --session s1 --kind gate --note "BLOCKED on round 3" >/dev/null
run_state "$bd_a" claim docs/plan.md 1 --session s1 >/dev/null
printf '2026-01-01T00:00:00Z\n' > "$wsbd/activity/s1"
run_state "$bd_a" snapshot docs/plan.md --session s1 >/dev/null; git -C "$bd_a" push -q origin hyperpowers/state 2>/dev/null
if [ "$(cat "$wsbd/activity/s1")" != "2026-01-01T00:00:00Z" ]; then pass "snapshot --session stamps activity"; else fail "snapshot --session stamps activity"; fi
git -C "$bd_b" fetch -q origin 2>/dev/null; git -C "$bd_b" switch -q -c feat origin/feat 2>/dev/null
run_state "$bd_b" sync docs/plan.md >/dev/null 2>&1; wsbdb=$(run_sdd_dir "$bd_b" docs/plan.md 2>/dev/null)
if [ "$(sed -n 's/^kind=//p' "$wsbdb/waiting/s1" 2>/dev/null)" = gate ] && [ -f "$wsbdb/activity/s1" ]; then pass "waiting and activity records travel with the snapshot"; else fail "records travel ($(ls "$wsbdb" 2>/dev/null | tr '\n' ' '))"; fi
# The board on host B: one session, one waiting record, the frontier, the held task.
out=$(run_state "$bd_b" board docs/plan.md 2>/dev/null); rc=$?
first=$(printf '%s\n' "$out" | sed -n 1p)
if [ "$rc" -eq 0 ] && [ "${first%% sync=*}" = "status=board" ] && printf '%s' "$first" | grep -q ' sessions=1 waiting=1 frontier=none$' && printf '%s\n' "$out" | grep -q '^session s1 task=1 since=.* host=[^ ]* waiting=gate waiting-since=.* note=BLOCKED%20on%20round%203 silence=[0-9]* quiet-since=none$' && printf '%s\n' "$out" | grep -q '^held task=1 owner=s1 since='; then pass "the board lists the session with its host and silence, its wait, the held task and an empty frontier"; else fail "board lines (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
# diverged: both hosts edit the same report and snapshot; B's board still prints, with sync=diverged.
printf 'A\n' > "$wsbd/task-1-report.md"; run_state "$bd_a" snapshot docs/plan.md >/dev/null; git -C "$bd_a" push -q origin hyperpowers/state 2>/dev/null
printf 'B\n' > "$wsbdb/task-1-report.md"; run_state "$bd_b" snapshot docs/plan.md >/dev/null
out=$(run_state "$bd_b" board docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | sed -n 1p | grep -q '^status=board sync=diverged' && printf '%s\n' "$out" | grep -q '^session s1 '; then pass "a diverged state branch prints the local board with sync=diverged"; else fail "board diverged (rc=$rc: $(sed -n 1p <<<"$out"))"; fi
# quiet: a held claim, no waiting record, old activity.
run_state "$bd_a" wait docs/plan.md --session s1 --clear >/dev/null; printf '2026-01-01T00:00:00Z\n' > "$wsbd/activity/s1"
out=$(run_state "$bd_a" board docs/plan.md 2>/dev/null)
if printf '%s\n' "$out" | grep -q '^session s1 task=1 .* waiting=none .* silence=[0-9]\{6,\} quiet-since=2026-01-01T00:00:00Z$'; then pass "a silent holder is quiet since its last activity, with the silence in seconds"; else fail "quiet ($(printf '%s' "$out" | tr '\n' '|'))"; fi
# Every sync outcome prints the local board with exit 0: offline (dead remote), plain, no-remote.
git -C "$bd_a" remote set-url origin "$TEST_ROOT/does-not-exist.git"
out=$(run_state "$bd_a" board docs/plan.md 2>"$TEST_ROOT/bd.err"); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | sed -n 1p | grep -q '^status=board sync=offline' && printf '%s\n' "$out" | grep -q '^session s1 '; then pass "a failed fetch prints the local board with sync=offline"; else fail "board offline (rc=$rc: $(sed -n 1p <<<"$out"))"; fi
git -C "$bd_a" remote set-url origin "$PAIR_REMOTE"
make_repo "$TEST_ROOT/bd0"; mkdir -p "$TEST_ROOT/bd0/docs"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$TEST_ROOT/bd0/docs/plan.md"; git -C "$TEST_ROOT/bd0" add docs; git -C "$TEST_ROOT/bd0" commit -qm plan
run_sdd_dir "$TEST_ROOT/bd0" docs/plan.md >/dev/null 2>&1
out=$(run_state "$TEST_ROOT/bd0" board docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | sed -n 1p | grep -q '^status=board sync=no-remote'; then pass "a repository without a remote prints its board with sync=no-remote"; else fail "board no-remote (rc=$rc: $(sed -n 1p <<<"$out"))"; fi
# plain: a repository with a remote whose state fell back to the plain backend.
make_pair bdp; bdp_a=$PAIR_A
ensure "$bdp_a" HYPERPOWERS_TEST_FAIL_WORKTREE_ADD=1 >/dev/null 2>&1
mkdir -p "$bdp_a/docs"; printf '# P\n\n**Spec:** docs/spec.md\n\n### Task 1: A\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$bdp_a/docs/plan.md"; git -C "$bdp_a" add docs; git -C "$bdp_a" commit -qm plan
wsbdp=$(run_sdd_dir "$bdp_a" docs/plan.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan.md\n' > "$wsbdp/progress.md"
out=$(run_state "$bdp_a" board docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | sed -n 1p | grep -q '^status=board sync=plain'; then pass "a plain-backend repository prints its board with sync=plain"; else fail "board plain (rc=$rc: $(sed -n 1p <<<"$out"))"; fi
# Leftover branches and siblings.
git -C "$bd_a" branch "feat.$(basename "$wsbd" | sed 's/.*-//').task-9" feat
printf '# Q\n\n**Spec:** docs/spec.md\n\n### Task 1: Z\n\n**Risk tier:** standard\n\n**Depends on:** none\n' > "$bd_a/docs/plan2.md"; git -C "$bd_a" add docs; git -C "$bd_a" commit -qm plan2
wsbd2=$(run_sdd_dir "$bd_a" docs/plan2.md 2>/dev/null); printf '# SDD ledger — plan: docs/plan2.md\n' > "$wsbd2/progress.md"; run_state "$bd_a" register docs/plan2.md --session s2 --integration feat >/dev/null
out=$(run_state "$bd_a" board docs/plan.md 2>/dev/null)
if printf '%s\n' "$out" | grep -q "^leftover branch=feat\..*\.task-9$" && printf '%s\n' "$out" | grep -q "^sibling plan=$(basename "$wsbd2") spec=docs/spec.md integration=feat$"; then pass "the board lists leftover task branches and sibling plans"; else fail "leftovers and siblings ($(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$bd_a" board --repo "$bd_a" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 1p)" = "status=board plans=2" ] && [ "$(printf '%s\n' "$out" | grep -c '^plan ws=.* spec=docs/spec.md integration=feat ')" = 2 ]; then pass "board --repo groups the repository's open plans"; else fail "board --repo (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
printf 'Task 1: complete (commits 1111111..2222222, review clean)\nTask 2: complete (commits 3333333..4444444, review clean)\n' >> "$wsbd/progress.md"
run_state "$bd_a" claim docs/plan.md final --session s1 >/dev/null
printf '2026-01-01T00:00:00Z\n' > "$wsbd/activity/s1"
out=$(run_state "$bd_a" board docs/plan.md 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "^session s1 task=final since=[^ ]* .* host=$(hostname) waiting=none .* silence=[0-9]\{6,\} quiet-since=2026-01-01T00:00:00Z$"; then pass "the board shows the final holder with its host and silence age"; else fail "final holder row (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
out=$(run_state "$bd_a" board --repo "$bd_a" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "^lease branch=feat session=s1 plan=$(basename "$wsbd") closing=0$"; then pass "board --repo lists the branch leases with their holders"; else fail "board --repo leases (rc=$rc: $(printf '%s' "$out" | tr '\n' '|'))"; fi
run_state "$bd_a" claim docs/plan.md final --session s1 --release >/dev/null
```

- [ ] **Step 2: Run the section to verify it fails**

Harness `~/.cache/hyperpowers/pd-board-harness.sh`. Expected: every check `[FAIL]`.

- [ ] **Step 3: The helpers and the three subcommands**

In `sdd-common.sh` after `hp_utc_now`:

```bash
# <UTC timestamp as hp_utc_now prints> -> seconds since the epoch; GNU date
# reads -d, BSD date needs -j -f.
hp_utc_epoch() {
  date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null
}
```

`write_activity` exists since Task 3. `cmd_snapshot` parses `--session SID` and, when given and the workspace exists, calls `write_activity "$sid"` before `hp_commit_paths`.

```bash
# --- wait --------------------------------------------------------------------
# One record per session, written by its session only, so no lock: the write
# is beside-and-rename. The note is one line because the board prints it on
# one line and a human reads it there.
cmd_wait() {
  local plan="" sid="" kind="" task="none" note="" clear=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) [ $# -ge 2 ] || usage; sid=$2; shift 2 ;;
      --kind) [ $# -ge 2 ] || usage; kind=$2; shift 2 ;;
      --task) [ $# -ge 2 ] || usage; task=$2; shift 2 ;;
      --note) [ $# -ge 2 ] || usage; note=$2; shift 2 ;;
      --clear) clear=1; shift ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  [ -n "$plan" ] && [ -n "$sid" ] || usage
  resolve_plan "$plan"
  [ -f "$WSDIR/progress.md" ] || { echo "status=no-workspace"; return 2; }
  if [ "$clear" -eq 1 ]; then rm -f "$WSDIR/waiting/$sid"; write_activity "$sid"; echo "status=cleared"; return 0; fi
  case "$kind" in question|tasks|merge|gate|handoff) ;; *) echo "sdd-state: --kind must be question, tasks, merge, gate or handoff" >&2; echo "status=error"; return 2 ;; esac
  [ -n "$note" ] || { echo "sdd-state: --note is required" >&2; echo "status=error"; return 2; }
  case "$note" in *$'\n'*) echo "sdd-state: the note must be one line" >&2; echo "status=error"; return 2 ;; esac
  mkdir -p "$WSDIR/waiting" || { echo "status=error"; return 2; }
  printf 'session=%s\ntask=%s\nkind=%s\nsince=%s\nnote=%s\nworktree=%s\nbranch=%s\nhost=%s\n' "$sid" "$task" "$kind" "$(hp_utc_now)" "$note" "$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)" "$(git branch --show-current 2>/dev/null || echo detached)" "$(hostname)" > "$WSDIR/waiting/$sid.new" && mv -f "$WSDIR/waiting/$sid.new" "$WSDIR/waiting/$sid" || { echo "status=error"; return 2; }
  write_activity "$sid"
  echo "status=waiting kind=$kind"
}

# --- board -------------------------------------------------------------------
# For a human reader: who holds what, who waits on what, and what is
# claimable. It syncs first when there is a remote and prints from local
# state whatever sync said, because an unreachable remote is no reason to
# hide the local board.
board_field() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1; }
cmd_board() {
  local plan="" code="" repo="" syncs="" first sid line sessions="" waiting=0 n task since wt br wkind wsince note act quiet now ts frontier line2 integ spec held="" d other ws8 b host silence rc
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) [ $# -ge 2 ] || usage; repo=$2; shift 2 ;;
      --code-repo) [ $# -ge 2 ] || usage; code=$2; shift 2 ;;
      -*) usage ;;
      *) [ -z "$plan" ] || usage; plan=$1; shift ;;
    esac
  done
  if [ -n "$repo" ]; then board_repo "$repo"; return $?; fi
  [ -n "$plan" ] || usage
  resolve_plan "$plan"
  # The code repository, for the leftover branches: a given --code-repo or
  # the cwd's repository is checked against the plan line before any output;
  # with neither there are no leftover lines.
  [ -n "$code" ] || code=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  [ -z "$code" ] || code=$(code_repo_arg "$code" "$WSDIR/progress.md") || { rc=$?; [ -z "$code" ] || printf '%s\n' "$code"; return "$rc"; }
  if hp_has_remote "$PLAN_DIR"; then
    syncs=$(bash "$0" sync "$plan" 2>"${TMPDIR:-/tmp}/sdd-board-sync.$$" | head -n 1); syncs=${syncs#status=}; syncs=${syncs%% *}
    case "$syncs" in up-to-date|fast-forwarded|merged|ahead|created|absent|no-remote|assumed-absent|plain) ;; *) sed -n 1p "${TMPDIR:-/tmp}/sdd-board-sync.$$" >&2 ;; esac
    rm -f "${TMPDIR:-/tmp}/sdd-board-sync.$$"
  else
    syncs=no-remote
  fi
  [ -n "$syncs" ] || syncs=error
  line=$(plan_line_of "$WSDIR/progress.md"); integ=$(plan_field "$line" integration); spec=$(plan_field "$line" spec)
  now=$(hp_utc_epoch "$(hp_utc_now)")
  # Every session that left a trace: a claim, a waiting record, an activity file or a session line.
  sessions=$( { for d in "$WSDIR"/claims/task-* "$WSDIR"/claims/final; do [ -f "$d/owner" ] && board_field "$d/owner" session; done; ls "$WSDIR/waiting" 2>/dev/null; ls "$WSDIR/activity" 2>/dev/null; sed -n 's/^session \([^:]*\):.*/\1/p' "$WSDIR/progress.md"; } | sed '/^$/d' | sort -u)
  frontier=$(next_classify board-reader 2>/dev/null | sed -n 's/^status=next tasks=\([^ ]*\).*/\1/p'); [ -n "$frontier" ] || frontier=none
  out_lines=""
  for sid in $sessions; do
    task=none; since=none
    for d in "$WSDIR"/claims/task-* "$WSDIR"/claims/final; do
      [ -f "$d/owner" ] || continue; [ "$(board_field "$d/owner" session)" = "$sid" ] || continue
      n=${d##*/}; n=${n#task-}; task=$n; since=$(board_field "$d/owner" time)
      if [ "$n" != final ] && grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md"; then task=none; since=none; else break; fi
    done
    wt=$(grep -E "^session $sid: mode " "$WSDIR/progress.md" | tail -n 1 | sed -n 's/.* at \(.*\) started .*/\1/p'); [ -n "$wt" ] || wt=unknown
    br=$(grep -E "^session $sid: mode " "$WSDIR/progress.md" | tail -n 1 | sed -n 's/.* on \([^ ]*\) .*/\1/p'); [ -n "$br" ] || br=unknown
    wkind=none; wsince=none; note=none
    if [ -f "$WSDIR/waiting/$sid" ]; then wkind=$(board_field "$WSDIR/waiting/$sid" kind); wsince=$(board_field "$WSDIR/waiting/$sid" since); note=$(enc "$(board_field "$WSDIR/waiting/$sid" note)"); waiting=$((waiting + 1)); fi
    host=""
    for d in "$WSDIR"/claims/task-* "$WSDIR"/claims/final; do
      [ -f "$d/owner" ] || continue; [ "$(board_field "$d/owner" session)" = "$sid" ] || continue
      host=$(board_field "$d/owner" host); break
    done
    [ -n "$host" ] || [ ! -f "$WSDIR/waiting/$sid" ] || host=$(board_field "$WSDIR/waiting/$sid" host)
    [ -n "$host" ] || host=unknown
    silence=none; act=$(head -n 1 "$WSDIR/activity/$sid" 2>/dev/null)
    if [ -n "$act" ]; then ts=$(hp_utc_epoch "$act"); [ -z "$ts" ] || silence=$((now - ts)); fi
    quiet=none
    if [ "$task" != none ] && [ "$wkind" = none ]; then
      if [ "$silence" = none ] || [ "$silence" -ge 1800 ]; then quiet=${act:-unknown}; fi
    fi
    out_lines="$out_lines
session $sid task=$task since=$since worktree=$(enc "$wt") branch=$br host=$host waiting=$wkind waiting-since=$wsince note=$note silence=$silence quiet-since=$quiet"
  done
  for d in "$WSDIR"/claims/task-*; do
    [ -f "$d/owner" ] || continue; n=${d##*/task-}
    grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md" || held="$held
held task=$n owner=$(board_field "$d/owner" session) since=$(board_field "$d/owner" time)"
  done
  echo "status=board sync=$syncs sessions=$(printf '%s\n' "$sessions" | grep -c .) waiting=$waiting frontier=$frontier"
  printf '%s\n' "$out_lines" | sed '/^$/d'
  printf '%s\n' "$held" | sed '/^$/d'
  if [ -n "$integ" ] && [ -n "$code" ] && [ -d "$code" ]; then
    ws8=$(ws8_of "$WS")
    for b in $(git -C "$code" for-each-ref --format='%(refname:short)' "refs/heads/$integ.$ws8.task-*" 2>/dev/null); do
      n=${b##*.task-}; n=${n%%.*}
      if grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$WSDIR/progress.md" || [ "$(board_field "$WSDIR/claims/task-$n/owner" branch)" != "$b" ]; then echo "leftover branch=$b"; fi
    done
  fi
  for d in "$ROOT"/plans/*/; do
    [ -f "$d/progress.md" ] || continue; [ "${d%/}" != "$WSDIR" ] || continue
    other=$(plan_line_of "$d/progress.md"); [ -n "$other" ] || continue
    if [ "$(plan_field "$other" spec)" = "$spec" ] || [ "$(plan_field "$other" integration)" = "$integ" ]; then echo "sibling plan=$(basename "${d%/}") spec=$(plan_field "$other" spec) integration=$(plan_field "$other" integration)"; fi
  done
  return 0
}
board_repo() { # <repo dir>: every open workspace, grouped by spec then branch, then the leases
  local repo=$1 ensure root d line n_s n_w held lines="" count=0 c f
  ensure=$(hp_ensure_checkout "$repo") || { echo "status=error"; return 2; }
  root=${ensure#* }
  for d in "$root"/plans/*/; do
    [ -f "$d/progress.md" ] || continue
    line=$(plan_line_of "$d/progress.md"); count=$((count + 1))
    n_s=$( { for c in "$d"/claims/task-* "$d"/claims/final; do [ -f "$c/owner" ] && board_field "$c/owner" session; done; ls "$d/waiting" 2>/dev/null; } | sed '/^$/d' | sort -u | grep -c .)
    n_w=$(ls "$d/waiting" 2>/dev/null | grep -c .)
    held=""; for c in "$d"/claims/task-*; do [ -f "$c/owner" ] || continue; n=${c##*/task-}; grep -Eq "(^|[^A-Za-z0-9])Task $n: complete" "$d/progress.md" || held="$held,$n"; done
    lines="$lines
$(plan_field "$line" spec)|$(plan_field "$line" integration)|plan ws=$(basename "${d%/}") spec=$(plan_field "$line" spec) integration=$(plan_field "$line" integration) sessions=$n_s waiting=$n_w held=${held#,}"
  done
  echo "status=board plans=$count"
  printf '%s\n' "$lines" | sed '/^$/d' | sort -t'|' -k1,1 -k2,2 | cut -d'|' -f3-
  c=$(hp_checkout_path "$repo") || return 2
  for f in "$c".final-*; do
    [ -f "$f" ] || continue
    echo "lease branch=$(board_field "$f" branch) session=$(board_field "$f" session) plan=$(board_field "$f" plan) closing=$(board_field "$f" closing)"
  done
}
```

Usage lines: `wait PLAN_FILE --session SID (--kind KIND [--task N] --note TEXT | --clear)`, `board PLAN_FILE [--code-repo DIR]   |   board --repo DIR`, `snapshot PLAN_FILE [-m MSG] [--session SID]`; dispatch `wait) cmd_wait "$@" ;;` and `board) cmd_board "$@" ;;`. The board's first line is the status line and the table follows, the one exception to the one-line grammar the spec grants.

- [ ] **Step 4: Run the section to verify it passes**

Run the harness. Expected: every `board` check `[PASS]`.

- [ ] **Step 5: Lint and commit**

```bash
git add skills/subagent-driven-development/scripts/sdd-common.sh skills/subagent-driven-development/scripts/sdd-state tests/sdd/test-sdd-state.sh
git commit -m "feat(sdd-state): wait records what a session waits on, and board prints every session, the frontier, holders, leftovers and siblings"
```

### Task 9: A second finish of a shared spec, and the finishing skill's lease steps

**Risk tier:** high — the decision records compiler is a durable-record writer, and the finishing skill's teardown is destructive git.

**Depends on:** Task 8


**Files:**
- Modify: `skills/finishing-a-development-branch/scripts/decisions-compile` (`outcome_line`, `render_spec`, `render_record`)
- Modify: `skills/finishing-a-development-branch/SKILL.md` (Step 1 item 5, Step 4's menu rule, Step 5 Option 1, Step 6)
- Test: `tests/claude-code/test-decisions-compile.sh` (section 12, two plans of one spec), `tests/sdd/test-sdd-contract.sh` (needles for the finishing text)

**Interfaces:**
- Consumes: the compiler's `plan_rel`, `today`, `existing_field`, `existing_notes`, `write_if_changed`; `sdd-state lease` and `board --repo` (Tasks 5 and 8) from the skill text.
- Produces: the Outcome line `**Outcome:** implemented <date> (<plan basename>)[, <date> (<plan basename>)]...; <n> decisions under <dir>/.`, where a run without `--plan` writes `<date>` alone and a run with `--plan` appends its entry unless the line already names that plan; an existing line of the older shape `implemented <date>;` is kept as its first entry. `Recorded:` lists every plan removed at a finish: `...; plan <A> removed at finish; plan <B> removed at finish`. "What implementation changed" holds one paragraph per plan that supplied notes, each opening `From <plan basename>: `, the earlier paragraphs kept verbatim; a record whose single existing paragraph has no prefix gets the first plan's prefix when a second plan adds one. Finishing skill text: item 5 states that a spec with an Outcome line is recompiled, never refused; Step 4 runs `sdd-state board --repo` on the plan file's repository (`git -C "$(dirname <plan>)" rev-parse --show-toplevel`, where the dossier lives, which is not the code repository when the plan lives elsewhere) and offers the merge option only when it lists no other open plan on the integration branch, naming the open plan otherwise; Option 1 runs `sdd-state lease PLAN_FILE --closing --session SID` before the merge and treats `sibling-open` as "show the menu again without the merge option"; every option ends with the session detaching its worktree (`git switch --detach`, when the integration branch is checked out there) and then, as the last action, `sdd-state lease PLAN_FILE --release --session SID`.

**Mirror:** `tests/claude-code/test-decisions-compile.sh:375-430` (the Outcome assertions and `write_spec`/`run_compile` helpers).

- [ ] **Step 1: Write the failing compiler fixtures**

Append to `tests/claude-code/test-decisions-compile.sh` before its closing status block, in the style of section 11:

```bash
# --- 12. two plans of one spec: the second finish recompiles --------------
r12="$TEST_ROOT/r12"; make_repo "$r12"
write_spec "$r12" shared-design.md <<'SPEC'
# Shared

## Decisions

- First decision. Why it holds.
- Second decision. Why it holds.
SPEC
printf '# A\n\n**Spec:** docs/hyperpowers/specs/shared-design.md\n' > "$r12/docs/hyperpowers/plans/a.md"
printf '# B\n\n**Spec:** docs/hyperpowers/specs/shared-design.md\n' > "$r12/docs/hyperpowers/plans/b.md"
git -C "$r12" add .; git -C "$r12" commit -qm "spec and plans"
printf '# Decision notes: docs/hyperpowers/specs/shared-design.md\n\n## Decision 1\nPlan A changed the first thing.\n\n## Decision 2\nNo change.\n' > "$TEST_ROOT/r12-notes-a.md"
run_compile "$r12" docs/hyperpowers/specs/shared-design.md --plan docs/hyperpowers/plans/a.md --notes "$TEST_ROOT/r12-notes-a.md" >/dev/null 2>&1
spec12="$r12/docs/hyperpowers/specs/shared-design.md"
if [ "$(sed -n 3p "$spec12")" = "**Outcome:** implemented $(date -u +%Y-%m-%d) (a.md); 2 decisions under docs/hyperpowers/decisions/." ]; then pass "a finish with a plan names it in the Outcome line"; else fail "first Outcome (got: $(sed -n 3p "$spec12"))"; fi
git -C "$r12" commit -qm "records for a" >/dev/null 2>&1
rec12=$(ls "$r12"/docs/hyperpowers/decisions/*first-decision*.md)
printf '# Decision notes: docs/hyperpowers/specs/shared-design.md\n\n## Decision 1\nPlan B changed it again.\n\n## Decision 2\nNo change.\n' > "$TEST_ROOT/r12-notes-b.md"
out=$(run_compile "$r12" docs/hyperpowers/specs/shared-design.md --plan docs/hyperpowers/plans/b.md --notes "$TEST_ROOT/r12-notes-b.md" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(sed -n 3p "$spec12")" = "**Outcome:** implemented $(date -u +%Y-%m-%d) (a.md), $(date -u +%Y-%m-%d) (b.md); 2 decisions under docs/hyperpowers/decisions/." ]; then pass "a second finish appends its plan to the Outcome line"; else fail "second Outcome (rc=$rc: $(sed -n 3p "$spec12"))"; fi
if grep -q '^- Recorded: .*; plan docs/hyperpowers/plans/a.md removed at finish; plan docs/hyperpowers/plans/b.md removed at finish$' "$rec12"; then pass "Recorded lists both plans"; else fail "Recorded both plans ($(grep '^- Recorded' "$rec12"))"; fi
if grep -q '^From a.md: Plan A changed the first thing.$' "$rec12" && grep -q '^From b.md: Plan B changed it again.$' "$rec12"; then pass "each plan's notes are their own paragraph, the first kept"; else fail "per-plan paragraphs ($(sed -n '/What implementation changed/,$p' "$rec12" | tr '\n' '|'))"; fi
out=$(run_compile "$r12" docs/hyperpowers/specs/shared-design.md --plan docs/hyperpowers/plans/b.md --notes "$TEST_ROOT/r12-notes-b.md" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(grep -c '(b.md)' "$spec12")" = 1 ] && [ "$(grep -c '^From b.md:' "$rec12")" = 1 ]; then pass "re-running the second finish adds nothing twice"; else fail "idempotent second finish (rc=$rc)"; fi
```

- [ ] **Step 2: Run the compiler suite to verify the new section fails**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: the four new checks `[FAIL]`, the rest `[PASS]`.

- [ ] **Step 3: The compiler changes**

Replace `outcome_line` and `render_spec` (`decisions-compile:505-520`):

```bash
# The Outcome line names every plan that implemented the spec, with its date:
# "implemented <date> (<plan>), <date> (<plan>); <n> decisions under <dir>/."
# A run without --plan writes a bare date; an older line's bare date is kept
# as its first entry. A plan already named is not named twice.
outcome_entries() {  # existing line or empty -> "date (plan), ..." with this run's entry added
  local existing=$1 entries entry
  entries=$(printf '%s' "$existing" | sed -n 's/^\*\*Outcome:\*\* implemented \(.*\); [0-9][0-9]* decisions.*/\1/p')
  if [ -n "$plan_rel" ]; then entry="$today ($(basename "$plan_rel"))"; else entry="$today"; fi
  if [ -z "$entries" ]; then printf '%s' "$entry"; return; fi
  if [ -n "$plan_rel" ] && printf '%s' "$entries" | grep -qF "($(basename "$plan_rel"))"; then printf '%s' "$entries"; return; fi
  if [ -z "$plan_rel" ]; then printf '%s' "$entries"; return; fi
  printf '%s, %s' "$entries" "$entry"
}
outcome_line() { printf '**Outcome:** implemented %s; %s decisions under %s/.' "$1" "$count" "$records_rel"; }
render_spec() {  # the spec text with its Outcome line written or rewritten
  local current line
  current=$(head -n 30 "$spec_abs" | grep -m 1 '^\*\*Outcome:\*\*' || true)
  line=$(outcome_line "$(outcome_entries "$current")")
  if [ -n "$current" ]; then
    awk -v line="$line" 'NR <= 30 && !r && /^\*\*Outcome:\*\*/ { print line; r = 1; next } { print }' "$spec_abs"
  else
    awk -v line="$line" '
      NR == 1 && /^# / { print; if ((getline nxt) > 0) { if (nxt ~ /^$/) { print ""; print line; print "" } else { print ""; print line; print ""; print nxt } } else { print ""; print line; print "" }; next }
      NR == 1 { print line; print ""; print; next }
      { print }' "$spec_abs"
  fi
}
```

In `render_record`, replace the `Recorded:` and notes assembly:

```bash
  recorded=$rec_date
  if [ "$notes_body" != "Nothing recorded." ]; then recorded="$recorded; notes from the branch diff by a subagent at finish"; fi
  # Every plan a finish removed stays named, in order, each once.
  plans_seen=""
  if [ "${existing[n]}" = 1 ]; then
    rec_full=$(existing_field "$target" Recorded)
    plans_seen=$(printf '%s' "$rec_full" | tr ';' '\n' | sed -n 's/^ *plan \(.*\) removed at finish$/\1/p')
  fi
  if [ -n "$plan_rel" ] && ! printf '%s\n' "$plans_seen" | grep -qxF "$plan_rel"; then plans_seen="$plans_seen
$plan_rel"; fi
  for p in $(printf '%s\n' "$plans_seen" | sed '/^$/d'); do recorded="$recorded; plan $p removed at finish"; done
```

and the notes body: when `--plan` is given and the notes file has text for `n`, the new paragraph is `From <plan basename>: <text>`; an existing body is kept, with a bare first paragraph gaining `From <first plan basename>: ` when a second plan adds one (the first plan basename is the first `plan ... removed at finish` entry); a paragraph for this plan already present is replaced, not duplicated:

```bash
  if $notes_valid && [ -f "$tmp/note-$n.txt" ] && [ -n "$plan_rel" ]; then
    new_par="From $(basename "$plan_rel"): $(cat "$tmp/note-$n.txt")"
    first_plan=$(printf '%s\n' "$plans_seen" | sed '/^$/d' | head -n 1)
    existing_body=${notes_body:-}
    [ "$existing_body" != "Nothing recorded." ] || existing_body=""
    if [ -n "$existing_body" ] && ! printf '%s' "$existing_body" | grep -q '^From '; then existing_body="From $(basename "$first_plan"): $existing_body"; fi
    existing_body=$(printf '%s\n' "$existing_body" | awk -v p="From $(basename "$plan_rel"): " 'BEGIN{RS=""; ORS="\n\n"} index($0, p) != 1 {print}')
    notes_body=$(printf '%s%s' "${existing_body:+$existing_body
}" "$new_par" | sed '/^$/N;/^\n$/D')
  elif $notes_valid && [ -f "$tmp/note-$n.txt" ]; then
    notes_body=$(cat "$tmp/note-$n.txt")
  fi
  [ -n "${notes_body:-}" ] || notes_body="Nothing recorded."
```

(`p`, `new_par`, `first_plan`, `existing_body`, `plans_seen`, `rec_full` join `render_record`'s `local` list.) The compiler's own fixtures for a single plan keep passing: a first finish writes `From <plan>: ` only when the record already existed with notes from another plan, so section 11's `Nothing recorded.` and single-paragraph assertions are unchanged; run them to confirm, and if an assertion compares a body that now carries the prefix, the prefix applies only on the second plan by the rule above.

- [ ] **Step 4: Run the compiler suite to verify it passes**

Run: `bash tests/claude-code/test-decisions-compile.sh`
Expected: `STATUS: PASSED` (every section).

- [ ] **Step 5: The finishing skill text**

In `skills/finishing-a-development-branch/SKILL.md`:

Step 1 item 5, after "The spec must be clean before the compile": add the sentence

```
A spec that already carries an Outcome line is a spec another plan finished
first; the compiler recompiles it, adding this plan to the Outcome line and
its notes as their own paragraph, and never refuses it.
```

Step 4, before "**Normal repo and named-branch worktree — present exactly these 3 options:**", add:

```
**Plans that share the integration branch.** When the hand-off names a
dossier (SDD), run `scripts/sdd-state board --repo "$(git -C "$(dirname <plan>)" rev-parse --show-toplevel)"`
from the subagent-driven-development skill's directory: the repository is
the plan file's, where the dossier lives, which is not the code repository
when the plan lives elsewhere. When it lists
another open plan whose `integration=` is this branch, the merge option is
withheld: present the three-option menu with option 1 replaced by the line
`1. (merge withheld: plan <ws> is still open on this branch)` and accept
only options 2 and 3; say which plan is open.
```

Step 5 Option 1, before `git checkout <base-branch>`:

```bash
# SDD only: mark the branch closing under the locks; a sibling that opened
# since the board was printed makes this sibling-open, which means show the
# menu again without the merge option.
scripts/sdd-state lease <plan> --closing --session <sid>
```

and after `git branch -d <feature-branch>` in the "Once the merged result is green" paragraph, and at the end of Options 2 and 3, in this order on every path:

```bash
git switch --detach                                        # SDD only, when the integration branch is checked out here
scripts/sdd-state lease <plan> --release --session <sid>   # SDD only, the last action; status=no-lease is fine
```

Step 6 opens with: "SDD only: the integration branch is checked out nowhere while sessions work; detach before the lease is released, never after."

Add to `tests/sdd/test-sdd-contract.sh` beside the `$FIN` needles:

```bash
assert_contains "$FIN" "the compiler recompiles it, adding this plan to the Outcome line" "finishing recompiles a spec with an Outcome line"
assert_contains "$FIN" "merge withheld: plan <ws> is still open on this branch" "finishing withholds the merge while a sibling plan is open"
assert_contains "$FIN" "sdd-state lease <plan> --closing --session <sid>" "finishing marks the branch closing before the merge"
assert_contains "$FIN" "sdd-state lease <plan> --release --session <sid>" "finishing releases the lease last"
assert_contains "$FIN" 'board --repo "$(git -C "$(dirname <plan>)" rev-parse --show-toplevel)"' "finishing reads the board from the plan repository"
```

- [ ] **Step 6: Run the contract suite, lint, commit**

Run: `bash tests/sdd/test-sdd-contract.sh` (expected `STATUS: PASSED`), `bash tests/shell-lint/test-lint-shell.sh`, the leak scan.

```bash
git add skills/finishing-a-development-branch/scripts/decisions-compile skills/finishing-a-development-branch/SKILL.md tests/claude-code/test-decisions-compile.sh tests/sdd/test-sdd-contract.sh
git commit -m "feat(finishing): a second plan of one spec recompiles its records, and the branch is closed and released through the lease"
```

### Task 10: The plan template's `Depends on:` line and the detached start

**Risk tier:** standard — behaviour-shaping doc surgery in two skills, with contract needles.

**Depends on:** Task 9


**Files:**
- Modify: `skills/writing-plans/SKILL.md:117-137` (the task template), `:80-87` (Global Constraints), `:181-215` (No Placeholders and the self-review)
- Modify: `skills/using-git-worktrees/SKILL.md:102-112` (the worktree creation) and its Quick Reference
- Test: `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks (text only).
- Produces: the template line `**Depends on:** none` under `**Risk tier:**`, its definition, the Merge-expected files rule in Global Constraints, the placeholder-scan item for a missing line, and the worktree skill's detached start and task-branch note.

- [ ] **Step 1: Add the contract needles (failing)**

Append to `tests/sdd/test-sdd-contract.sh`:

```bash
assert_contains "$WPLANS" "**Depends on:** none" "writing-plans template carries the Depends on line"
assert_contains "$WPLANS" "names the tasks whose completion lines must exist before this task may be claimed" "writing-plans defines the Depends on line"
assert_contains "$WPLANS" "**Merge-expected files:**" "writing-plans names merge-expected files in Global Constraints"
assert_contains "$WPLANS" "a task without a Depends on line" "writing-plans placeholder scan covers the Depends on line"
WT="$REPO_ROOT/skills/using-git-worktrees/SKILL.md"
assert_contains "$WT" "git worktree add --detach" "using-git-worktrees starts a later SDD session's worktree detached"
assert_contains "$WT" "the claim creates the task branch and the controller checks it out" "using-git-worktrees defers the task branch to the claim"
```

Run: `bash tests/sdd/test-sdd-contract.sh`. Expected: these six `[FAIL]`.

- [ ] **Step 2: writing-plans edits**

In the task template (`:120-124`), after the `**Risk tier:**` line and a blank line, add:

````
**Depends on:** none
````

and directly after the template block's closing fence, this paragraph:

```
The `**Depends on:**` line names the tasks whose completion lines must exist
before this task may be claimed: `none`, or `Task 1, Task 3`. It says
nothing about files; the pre-flight scan checks declared independence
against file and interface overlap separately. Every task carries the line;
a plan with no such line on any task is read as serial, each task after
every earlier one.
```

In Global Constraints (`:80-87`), after the existing bracketed description, add:

```
Name here, under **Merge-expected files:**, the files every task touches by
nature (a changelog, a test index), each in backticks: two independent tasks
that share only those files are not a conflict, and their merge-back
conflicts are resolved by hand like any other.
```

In the self-review's placeholder scan (`:209`), extend the item: "..., and a task without a Depends on line (a plan written under the dependency design carries one on every task)." In No Placeholders (`:181-200`), add the bullet "- A task with no `**Depends on:**` line (write `none` when there is none)".

- [ ] **Step 3: using-git-worktrees edits**

After the `git worktree add "$path" -b "$BRANCH_NAME"` block (`:108`), add:

````
**A later session of a plan that is already running** (the SDD skill says
so: the plan's ledger has a plan line naming an integration branch) starts
its worktree detached at that branch's head rather than on a new branch:

```bash
git worktree add --detach "$path" "<integration branch>"
cd "$path"
```

The integration branch itself is checked out nowhere while sessions work on
the plan; the claim creates the task branch and the controller checks it
out, and after each merge-back the worktree detaches again at the merged
head.
````

Add the Quick Reference row `| Later session on a running SDD plan | Detached worktree at the integration head (Step 1b) |`.

- [ ] **Step 4: Run the contract suite and commit**

Run: `bash tests/sdd/test-sdd-contract.sh`. Expected: `STATUS: PASSED`.

```bash
git add skills/writing-plans/SKILL.md skills/using-git-worktrees/SKILL.md tests/sdd/test-sdd-contract.sh
git commit -m "docs(skills): plans declare task dependencies and merge-expected files, and a later session's worktree starts detached"
```

### Task 11: The SDD skill text: register, next, merge-back, the board and the final train

**Risk tier:** standard — behaviour-shaping doc surgery in the skill under test by Task 14's scenario.

**Depends on:** Task 10


**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md` (Setup `:125-262`, the dispatch bullets `:358-430`, completion `:695-707`, Final Review `:724-804`, Finish `:805-847`, the process graph `:49-123`)
- Modify: `skills/subagent-driven-development/example-workflow.md` (the session line and the claim/merge-back lines)
- Test: `tests/sdd/test-sdd-contract.sh`

**Interfaces:**
- Consumes: every subcommand of Tasks 1 to 8 by name and status.
- Produces: the controller contract the scenario measures: register at Setup; `deps` quoted in the ledger and `deps --check` rows in the scan; the session line with `integrating`; `next` before every dispatch; claim then `git switch <branch>`; the `approved` line after the gate; `merge-back`, then `git switch --detach <head>` and `git branch -D <task branch>`, then the completion line; the conflict route; the waiting-board rule; `claim final`, the lease, `finish --session`; the hand-back shapes.

- [ ] **Step 1: Update and add the contract needles (failing)**

In `tests/sdd/test-sdd-contract.sh`, change the needle at `:403` to the new session-line shape and add:

```bash
assert_contains "$SDD" "session <sid>: mode <current-branch|new-branch|worktree> on <task branch or detached> integrating <integration branch> at <toplevel> started <UTC time>" "session line shape"
assert_contains "$SDD" "scripts/sdd-state register PLAN_FILE --session <sid> --integration <branch>" "Setup registers the plan"
assert_contains "$SDD" "scripts/sdd-state deps --check PLAN_FILE --ledger" "the scan runs the overlap check"
assert_contains "$SDD" "scripts/sdd-state next PLAN_FILE --session <sid>" "next before every dispatch"
assert_contains "$SDD" "A task held by another session is ordinary while next offers another" "a held task is ordinary with a frontier"
assert_contains "$SDD" "Task <N>: approved <sha7>" "the approved line after the gate"
assert_contains "$SDD" "scripts/sdd-state merge-back PLAN_FILE N --session <sid> --commit <sha>" "merge-back after the gate"
assert_contains "$SDD" "git switch --detach <merged head>" "the controller detaches at the merged head"
assert_contains "$SDD" "scripts/sdd-state wait PLAN_FILE --session <sid> --kind" "the waiting board rule"
assert_contains "$SDD" "scripts/sdd-state claim PLAN_FILE final --session <sid>" "the final train is claimed"
assert_contains "$SDD" "scripts/sdd-state finish PLAN_FILE --session <sid>" "finish takes the session"
assert_not_contains "$SDD" "Never dispatch multiple implementation subagents in parallel (conflicts)." "the old parallel sentence is replaced"
```

and update the example-workflow needles at `:166-168` only if the identity-line text changes (it does not; the session line in `example-workflow.md:9` changes to `session 1f3a9c: mode worktree on detached integrating feature-plan at /repo/.worktrees/feature-plan started 2026-10-20T10:00:00Z`, with no needle on it).

- [ ] **Step 2: Setup**

In the Setup bullets (`:125-262`): after the branch choice paragraph, add a bullet:

```
- Register the plan before anything else is claimed:
  `scripts/sdd-state register PLAN_FILE --session <sid> --integration <branch>`,
  where `<branch>` is the branch the branch choice produced (the plan's
  integration branch; later sessions read it from the ledger's plan line and
  pass the same). `registered` continues; `wrong-branch` means this plan is
  already running on another integration branch: switch to it or ask;
  `spec-branch-mismatch` means a sibling plan of this spec runs on another
  branch: use that branch; `branch-closing` means the plan's branch is being
  merged and deleted: wait for your human partner. A later session of a
  running plan starts its worktree detached at the integration head
  (using-git-worktrees says how) and never checks the integration branch
  out; a session in work-in-place mode runs `git switch --detach <branch>`
  before its first claim. When the plan file lives in another repository
  than the code, pass `--code-repo <code toplevel>` to every `sdd-state`
  call; an omitted option means the current repository, and a wrong one is
  `wrong-repo`.
- Quote the graph in the ledger: run `scripts/sdd-state deps PLAN_FILE` and
  append its lines after the scan table. The scan's conflict rows include
  `scripts/sdd-state deps --check PLAN_FILE --ledger <workspace>/progress.md`'s
  lines: each `conflict tasks=A,B ...` is a row for your human partner, settled
  by an amendment (`scripts/sdd-state amend PLAN_FILE --from <edited copy>
  --base <plan= blob> --message <subject>`, with `--accept 'tasks=A,B path=<p>'`
  when they accept the overlap) and never by editing the plan in the worktree
  alone, because the plan ref is what every session reads.
```

Change the session line's shape in the ledger-creation bullet to
`session <sid>: mode <current-branch|new-branch|worktree> on <task branch or detached> integrating <integration branch> at <toplevel> started <UTC time>`
and add: "Append a fresh session line whenever you move to a new task branch or detach; your newest line is your location."

- [ ] **Step 3: The task loop**

Replace the claim bullet (`:396-416`) with:

```
- Ask what to take: `scripts/sdd-state next PLAN_FILE --session <sid>`.
  `next tasks=<list>` names the claimable tasks in plan order, this
  session's own claims first; claim the first:
  `scripts/sdd-state claim PLAN_FILE N --session <sid>`. `claimed` prints the
  task branch and its base: check the branch out (`git switch <branch>`) and
  dispatch on it; `held` from `claim` after `next` offered the task is a race
  lost, run `next` again; `blocked` means the plan moved under you, run
  `next` again. A task held by another session is ordinary while next offers
  another: take what it offers. When `next` prints `none`: `complete` goes to
  the final train (Finish below); `assigned-complete` is reported and the
  session hands back; `held` and `blocked` mean post a waiting record
  (`scripts/sdd-state wait PLAN_FILE --session <sid> --kind tasks --note "<the
  held= and waiting= fields>"`), print `scripts/sdd-state board PLAN_FILE`,
  and hand back with the board's session lines in your message. Take a held
  task over only on your human partner's explicit yes to a question that
  names the holder and the time since (`--takeover`), recording the takeover
  beside the original identity; `own-blocked` means an amendment put a
  prerequisite under your own claim: post, print the board, hand back, and
  let your human partner remove the edge or let the prerequisite complete.
  `done`, `no-workspace` and `error` keep their handling.
```

Replace "- Never dispatch multiple implementation subagents in parallel (conflicts)." with "- One implementer at a time in this session: parallel work is other sessions' (one controller per task branch); never dispatch two implementers at once here."

In "5. Complete the task" (`:695-707`), replace the body with:

```
When the review comes back clean, in this order, each step idempotent on a
resume:

- Append `Task <N>: approved <sha7>` with the head the reviewers saw (every
  later approval of the same task appends a new line; the newest is what
  merges).
- Merge back: `scripts/sdd-state merge-back PLAN_FILE N --session <sid> --commit <sha>`.
  `merged` continues (`already=1` on a resume means the ref was moved
  before the crash). `conflict paths=<list>`: merge the integration branch
  into the task branch in your worktree (`git merge <integration>`), resolve
  through one implementer dispatch whose brief names the paths and both
  sides, re-run the task reviewer over the resolution and the task gate's
  re-review lens, append the new `approved` line, and retry. `checked-out`
  names a worktree or `lease:<sid>`: a final train holds the branch; post a
  `tasks` record and retry after it ends, or ask your human partner to move
  the checkout. `not-approved`, `not-holder`, `blocked`: your bookkeeping is
  behind; read the ledger and repair it before retrying.
- Detach at the merged head and drop the task branch:
  `git switch --detach <merged head>` then `git branch -D <task branch>`
  (its commits are on the integration branch now; a missing branch on a
  resume is fine).
- Append the completion line: `Task <N>: complete (commits <base7>..<head7>, review clean)`.
- Snapshot, mark the todo complete, and run `next`.

A task whose ledger has a `merged` line and no completion line is resumed
at the completion line, never redispatched.
```

- [ ] **Step 4: The waiting-board rule, Final Review and Finish**

Add a subsection "## The waiting board" before "## Risk Tiers":

```
Before you ask your human partner a question, hand back BLOCKED, meet an
empty frontier (`held` or `blocked`), or stop on a merge conflict, post what
you wait on: `scripts/sdd-state wait PLAN_FILE --session <sid> --kind
<question|tasks|merge|gate|handoff> [--task N] --note "<one line>"`, and put
the session lines of `scripts/sdd-state board PLAN_FILE` in what you write.
When you resume, clear it: `scripts/sdd-state wait PLAN_FILE --session <sid> --clear`.
The board is how your human partner finds the session that needs them among
several; a session that holds a claim and posts nothing shows as quiet
after half an hour, which is where they look for a permission prompt.
```

In Final Review (`:724-804`), replace the paragraph "Final review requires a `Task <N>: complete` line ... rather than finishing the plan." with:

```
The final train is claimed. When `next` says `complete`, run
`scripts/sdd-state claim PLAN_FILE final --session <sid>`: `claimed` means
this session runs the final review, the final gate and Finish; `blocked`
names tasks still open (claims without completion lines elsewhere: wait or
ask); `held` names the session that holds it, or `lease=<sid> plan=<ws>`
when a sibling plan's final holds the branch: post a `tasks` record naming
the holder, print the board, and hand back. The holder checks the
integration branch out in its own worktree (`git switch <integration>`), the
one time a session does so, and runs the review package, the final
reviewer, the fix wave and the final Codex gate on it; its fix commits land
on the integration branch directly, which the lease makes safe.
```

In Finish (`:805-847`), item 2 becomes `scripts/sdd-state finish PLAN_FILE --session <sid>` with: "`not-holder` or `no-final-claim` (exit 11): this session does not hold the final train; stop and hand back." Add after item 3: "4. **Keep the lease through the branch action.** `finish` leaves the branch lease in place; hyperpowers:finishing-a-development-branch marks the branch closing before a merge and releases the lease after whichever option your human partner chose. Hand it the plan path and your session id for that. When the final ends with a hand-back instead, detach your worktree first (`git switch --detach`) and then release the lease yourself, as the last action: `scripts/sdd-state lease PLAN_FILE --release --session <sid>`."

Update the process graph's nodes to name `next`, `merge-back` and the final claim, and `example-workflow.md` to show the new session line, a `next` line before each claim, an `approved` line, a `merge-back` line and the detach, and `claim final` before the final review.

- [ ] **Step 5: Run the contract suite and commit**

Run: `bash tests/sdd/test-sdd-contract.sh`. Expected: `STATUS: PASSED`.

```bash
git add skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/example-workflow.md tests/sdd/test-sdd-contract.sh
git commit -m "docs(sdd): sessions register, take what next offers, merge back after the gate, post to the board when blocked, and claim the final train"
```

### Task 12: Testing guide, usage comments and the changelog

**Risk tier:** standard — three files, one of them a script's usage block; the content is in this task but it is not one file.

**Depends on:** Task 11


**Files:**
- Modify: `docs/testing.md:25` (the `tests/sdd/` row's description), `CHANGELOG.md` (Unreleased), `skills/subagent-driven-development/scripts/sdd-state:1-26` (the header comment's usage and exit table)

- [ ] **Step 1: The header comment**

In `sdd-state`'s header, add the new usage lines (`deps`, `register`, `next`, `wait`, `board`, `merge-back`, `amend`, `lease`, `claim ... final`, `finish --session`, `snapshot --session`) in the shape of the existing ones, and extend the exit table with: `7 blocked | 8 conflict | 9 wrong-branch, spec-branch-mismatch | 11 not-holder, no-final-claim | 12 not-approved | 13 checked-out | 14 stale | 15 branch-closing, sibling-open`, keeping the existing entries. Note under "stdout": "board, deps and the refusals of amend and deps --check print their status line and then their lines".

- [ ] **Step 2: docs/testing.md**

Extend the `tests/sdd/` row's description with ", the dependency graph, claims with task branches, merge-back, the waiting board and the final lease (two sessions played from one shell)". No command changes.

- [ ] **Step 3: CHANGELOG**

Under `## Unreleased`, after the existing bullets, add:

```
- **Several sessions can work one plan, or sibling plans of one spec, at once.** Plans carry a `**Depends on:**` line per task (a plan without any is serial, as before); `sdd-state deps` reads the graph from the plan ref's head and `deps --check` names tasks that share files or interfaces without an edge; a session registers the plan's integration branch (`register`), asks `next` for the claimable frontier, claims a task and gets a task branch (`<integration>.<ws8>.task-N`), merges the approved commit back after its gate (`merge-back`, by the plumbing `sync` uses, under both repositories' locks, with a merge record that makes a retry idempotent), and claims the final train (`claim final`) with a lease on the branch that serializes sibling plans' finals; `wait` and `board` show who waits on what; `amend` is the plan ref's only writer; `finish` takes `--session`. Two sessions on one plan need this version on both.
- **A second plan of one spec recompiles its records.** The spec's Outcome line names every plan with its date, each record's `Recorded:` lists them, and each plan's notes are their own paragraph; the finishing skill withholds the merge while a sibling plan is open on the branch and releases the branch lease after the option runs.
- **Floors.** `merge-back` and `amend` need git 2.38 (`merge-tree --write-tree`) and refuse an older git by name; everything else keeps 2.31.
```

- [ ] **Step 4: Commit**

```bash
git add docs/testing.md CHANGELOG.md skills/subagent-driven-development/scripts/sdd-state
git commit -m "docs: the parallel-development subcommands in the usage, the testing guide and the changelog"
```

### Task 13: The live two-terminal run

**Risk tier:** standard — evidence, not code; it validates the two Assumptions.

**Depends on:** Task 12


**Files:**
- Create: `evals/evidence/2026-10-27-parallel-development/README.md` (in the hyperpowers-evals repository) with the transcript excerpts, the three board outputs, the integration branch's `git log --graph --oneline`, and the final suite's last lines
- Create: a throwaway repository under `~/.cache/hyperpowers/parallel-live/` (never committed)

**Interfaces:**
- Consumes: everything above, through two real Claude Code sessions in two terminals, each running `hyperpowers:subagent-driven-development` on the same plan from its own worktree.

- [ ] **Step 1: Build the throwaway repository**

```bash
R=~/.cache/hyperpowers/parallel-live/repo; rm -rf "$R"; mkdir -p "$R"; git -C "$R" init -q -b main
git -C "$R" commit -q --allow-empty -m init
mkdir -p "$R/docs/hyperpowers/specs" "$R/docs/hyperpowers/plans" "$R/src" "$R/tests"
printf '# Live spec\n\n## Decisions\n\n- Two files are written by two sessions. Decided for the live run.\n' > "$R/docs/hyperpowers/specs/2026-10-27-live-design.md"
cat > "$R/docs/hyperpowers/plans/2026-10-27-live.md" <<'PLAN'
# Live Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** docs/hyperpowers/specs/2026-10-27-live-design.md

**Goal:** Two independent files and one that reads both.

**Architecture:** Three shell scripts.

**Tech Stack:** bash.

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`

## Grounding

- none: a throwaway repository.

---

### Task 1: a.sh

**Risk tier:** standard — a script and its test, both given in full.

**Depends on:** none

**Files:**
- Create: `src/a.sh`
- Test: `tests/test-a.sh`

- [ ] **Step 1: Write the failing test** `tests/test-a.sh`: `#!/usr/bin/env bash` then `[ "$(bash src/a.sh)" = A ] && echo PASS || { echo FAIL; exit 1; }`
- [ ] **Step 2: Run it** (fails: no src/a.sh)
- [ ] **Step 3: Write `src/a.sh`**: `#!/usr/bin/env bash` then `echo A`
- [ ] **Step 4: Run it** (PASS)
- [ ] **Step 5: Commit** `git add src/a.sh tests/test-a.sh && git commit -m "feat: a"`

### Task 2: b.sh

**Risk tier:** standard — a script and its test, both given in full.

**Depends on:** none

**Files:**
- Create: `src/b.sh`
- Test: `tests/test-b.sh`

- [ ] **Step 1: Write the failing test** `tests/test-b.sh`: `[ "$(bash src/b.sh)" = B ] && echo PASS || { echo FAIL; exit 1; }`
- [ ] **Step 2: Run it** (fails)
- [ ] **Step 3: Write `src/b.sh`**: `echo B`
- [ ] **Step 4: Run it** (PASS)
- [ ] **Step 5: Commit** `git add src/b.sh tests/test-b.sh && git commit -m "feat: b"`

### Task 3: ab.sh

**Risk tier:** standard — a script and its test, both given in full.

**Depends on:** Task 1, Task 2

**Files:**
- Create: `src/ab.sh`
- Test: `tests/test-ab.sh`

- [ ] **Step 1: Write the failing test** `tests/test-ab.sh`: `[ "$(bash src/ab.sh)" = AB ] && echo PASS || { echo FAIL; exit 1; }`
- [ ] **Step 2: Run it** (fails)
- [ ] **Step 3: Write `src/ab.sh`**: `printf '%s%s\n' "$(bash src/a.sh)" "$(bash src/b.sh)"`
- [ ] **Step 4: Run it** (PASS)
- [ ] **Step 5: Commit** `git add src/ab.sh tests/test-ab.sh && git commit -m "feat: ab"`
PLAN
printf '# Changelog\n' > "$R/CHANGELOG.md"; git -C "$R" add .; git -C "$R" commit -qm "spec and plan"
# Two fresh Claude configurations: the host's settings (its env block, model
# pins and auth) without its installed plugins, so the only hyperpowers a
# session can load is the candidate handed to --plugin-dir. A plain `claude`
# would load .worktrees/plugin-install at the release tag and validate nothing.
CAND=$(git rev-parse --show-toplevel)
for n in 1 2; do C=~/.cache/hyperpowers/parallel-live/config-$n; rm -rf "$C"; mkdir -p "$C"; cp ~/.claude/settings.json "$C/settings.json"; done
git -C "$CAND" rev-parse HEAD > ~/.cache/hyperpowers/parallel-live/candidate-commit.txt; printf '%s\n' "$CAND" > ~/.cache/hyperpowers/parallel-live/candidate-path.txt
```

`$CAND` is this plan's worktree (the branch under implementation), run from inside it.

- [ ] **Step 2: Run the two sessions against the candidate**

Terminal 1, in `$R`: `CLAUDE_CONFIG_DIR=~/.cache/hyperpowers/parallel-live/config-1 claude --plugin-dir "$CAND"` and send "Execute docs/hyperpowers/plans/2026-10-27-live.md with subagent-driven-development; when asked, create a worktree." Terminal 2, in `$R`, once terminal 1's ledger shows `Task 1: branch`: `CLAUDE_CONFIG_DIR=~/.cache/hyperpowers/parallel-live/config-2 claude --plugin-dir "$CAND"` and send the same message. Before the run counts: each session's transcript (under `<config dir>/projects/`) shows its first `scripts/sdd-dir` call at a path under `$CAND`, not under `.worktrees/plugin-install`; a session running the installed plugin is void, is stopped, and is started again. Expected: terminal 2's Setup registers (`registered`), starts detached, `next` offers Task 2, both sessions run their tasks; the first to finish merges back (`merged`), the second's merge-back makes a merge commit; Task 3 is claimed by whichever session's `next` sees both complete; that session also claims `final` and the other hands back with the board. Run `sdd-state board` from a third terminal at three moments (both claimed, one merged, final claimed) and keep the output.

- [ ] **Step 3: Record the evidence**

Write `evals/evidence/2026-10-27-parallel-development/README.md` in the evals repository with: the candidate path and commit (`candidate-path.txt`, `candidate-commit.txt`) and the `sdd-dir` line from each transcript that proves the candidate loaded, the three board outputs verbatim, the plan's ledger as it stood before `finish` removed it (the ledger is gone from the state tip once the workspace is deleted: find the state commit that removed it with `git -C <state checkout> log -1 --format=%H hyperpowers/state -- plans/<ws>` and read `git -C <state checkout> show <that commit>^:plans/<ws>/progress.md`), `git -C "$R" log --graph --oneline <integration branch>`, the final suite's last lines, and a paragraph each on the two Assumptions (the detached worktree between tasks: did either controller stumble on it; the lock pair: any `lock held` line). Commit it in the evals repository (not here) with a one-sentence subject and no attribution line. Record the directory path and the evals commit in this plan's ledger.

### Task 14: The quorum scenario for the held-task rule

**Risk tier:** standard — a new scenario in the evals repository, measured against the current text as the control.

**Depends on:** Task 13


**Files (hyperpowers-evals repository):**
- Create: `evals/scenarios/sdd-held-task-takes-frontier/{story.md,setup.sh,checks.sh}` (case one)
- Create: `evals/scenarios/sdd-empty-frontier-posts-and-hands-back/{story.md,setup.sh,checks.sh}` (case two)
- Create: `evals/evidence/2026-10-27-parallel-development/scenario-runs/` (the verdicts)
- Modify: `evals/evidence/2026-10-27-parallel-development/README.md` (Task 13 creates it; this task adds the scenario section)

**Interfaces:**
- Consumes: the scenario anatomy (`evals/docs/scenario-authoring.md:40-128`), `setup-helpers run create_base_repo`, the verbs `check-transcript tool-arg-match`, `command-succeeds`, `file-exists`; the candidate plugin's `sdd-state` through `$SUPERPOWERS_ROOT` in `setup.sh`, as `sdd-plan-scoped-scratch/setup.sh` seeds a workspace with the candidate's `sdd-dir`.
- Produces: two scenarios whose `post()` proves, from the transcript and the harness home's cache, the behaviour the skill text prescribes.

**Mirror:** `evals/scenarios/sdd-plan-scoped-scratch/{setup.sh,checks.sh}`: a workspace pre-seeded through the candidate's scripts under the harness home (`../home/.cache`), the `coding-agents:` directive inside the first 21 lines, `pre()` asserting the seed exists.

- [ ] **Step 1: Case one, `setup.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
# Fixture: a 3-task plan with Depends on lines (1 and 2 independent, 3 after
# both) on branch feature/parallel, registered and with Task 1 claimed by a
# fixture session, through the candidate's own sdd-state so the records are
# exactly what a second live session would find. The agent under test is a
# second session: the skill says it takes Task 2, the claimable one, rather
# than stopping on the held Task 1 or taking it over.
setup-helpers run create_base_repo
git checkout -b feature/parallel
mkdir -p docs/hyperpowers/plans docs/hyperpowers/specs src tests
printf '# Spec\n\n## Decisions\n\n- One decision. For the fixture.\n' > docs/hyperpowers/specs/parallel-design.md
cat > docs/hyperpowers/plans/parallel.md <<'PLAN'
# Parallel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use hyperpowers:subagent-driven-development (recommended) or hyperpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** docs/hyperpowers/specs/parallel-design.md

**Goal:** Two independent files and one that reads both.

**Architecture:** Three shell scripts.

**Tech Stack:** bash.

## Global Constraints

- **Merge-expected files:** `CHANGELOG.md`

## Grounding

- none: a fixture repository.

---

### Task 1: a.sh

**Risk tier:** low — the complete file is below.

**Depends on:** none

**Files:**
- Create: `src/a.sh`

- [ ] **Step 1: Write `src/a.sh`**: `echo A`
- [ ] **Step 2: Commit** `git add src/a.sh && git commit -m "feat: a"`

### Task 2: b.sh

**Risk tier:** low — the complete file is below.

**Depends on:** none

**Files:**
- Create: `src/b.sh`

- [ ] **Step 1: Write `src/b.sh`**: `echo B`
- [ ] **Step 2: Commit** `git add src/b.sh && git commit -m "feat: b"`

### Task 3: ab.sh

**Risk tier:** low — the complete file is below.

**Depends on:** Task 1, Task 2

**Files:**
- Create: `src/ab.sh`

- [ ] **Step 1: Write `src/ab.sh`**: `printf '%s%s\n' "$(bash src/a.sh)" "$(bash src/b.sh)"`
- [ ] **Step 2: Commit** `git add src/ab.sh && git commit -m "feat: ab"`
PLAN
printf '# Changelog\n' > CHANGELOG.md
git add .
git -c user.name='Fixture' -c user.email='fixture@example.com' commit -q -m "plan and spec"
# Seed the dossier as a first session would: register, then claim Task 1,
# through the candidate's own scripts under the run's throwaway HOME (the
# derivation sdd-plan-scoped-scratch uses), so the agent's session finds
# exactly the records a live first session leaves.
CANDIDATE="${QUORUM_SUPERPOWERS_ROOT:-${SUPERPOWERS_ROOT:?SUPERPOWERS_ROOT not set}}/skills/subagent-driven-development/scripts"
HOME_DIR="$(dirname "$QUORUM_WORKDIR")/home"
cd "$QUORUM_WORKDIR"
run_candidate() { HOME="$HOME_DIR" XDG_CACHE_HOME="$HOME_DIR/.cache" bash "$CANDIDATE/$1" "${@:2}"; }
run_candidate sdd-state sync docs/hyperpowers/plans/parallel.md >/dev/null 2>&1 || true
ws=$(run_candidate sdd-dir docs/hyperpowers/plans/parallel.md 2>/dev/null)
# sdd-dir creates the workspace, not the ledger: the identity line comes first, as Setup writes it.
printf '# SDD ledger — plan: docs/hyperpowers/plans/parallel.md\n' > "$ws/progress.md"
printf 'session fixture-session: mode worktree on detached integrating feature/parallel at /fixture started 2026-10-27T00:00:00Z\n' >> "$ws/progress.md"
# The control arm predates register: seed the plan line by hand there, so both arms start from the same records.
if run_candidate sdd-state 2>&1 | grep -q ' register '; then
  run_candidate sdd-state register docs/hyperpowers/plans/parallel.md --session fixture-session --integration feature/parallel >/dev/null
else
  root7=$(git rev-list --max-parents=0 HEAD | sort | head -n 1 | cut -c1-7)
  printf 'plan: integration feature/parallel code-root %s plan-ref feature/parallel plan-root %s spec docs/hyperpowers/specs/parallel-design.md\n' "$root7" "$root7" >> "$ws/progress.md"
fi
run_candidate sdd-state claim docs/hyperpowers/plans/parallel.md 1 --session fixture-session >/dev/null
git switch -q --detach feature/parallel
```

`story.md` (frontmatter `id: sdd-held-task-takes-frontier`, `title: A second SDD session takes the claimable task while another holds Task 1`, `status: ready`, `quorum_tier: full`, `quorum_max_time: 45m`, `tags: subagent-driven-development, parallel, claims, next`): the Gauntlet-Agent plays a developer who says exactly "Another session of mine is already running this plan from its own worktree and holds Task 1. Please join it: use subagent-driven-development on docs/hyperpowers/plans/parallel.md from a new worktree." If asked about takeover, answer "No, the other session is still working." Done when the agent reports Task 2 complete or hands back. Acceptance Criteria: the agent invoked the SDD skill; it ran `sdd-state register` and `sdd-state next`; it claimed and worked Task 2 and never ran `claim ... 1 --takeover`; it did not stop at the held Task 1 before taking Task 2.

`checks.sh` (non-executable, functions only, the `coding-agents:` directive in the first 21 lines):

```bash
# A second session must take the claimable task (2) while Task 1 is held by
# the fixture session; it must neither stop on the held task nor take it over.
# coding-agents: claude, claude-auto, claude-vertex, claude-bedrock, claude-sonnet, claude-haiku

pre() {
    git-repo
    file-exists 'docs/hyperpowers/plans/parallel.md'
    command-succeeds 'find ../home/.cache -name progress.md -exec head -n 1 {} \; | grep -q "^# SDD ledger — plan: docs/hyperpowers/plans/parallel.md$"'
    command-succeeds 'find ../home/.cache -type d -path "*/claims/task-1" | grep -q .'
}

post() {
    check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
    check-transcript tool-arg-match Bash --matches 'command=sdd-state register'
    check-transcript tool-arg-match Bash --matches 'command=sdd-state next'
    check-transcript tool-arg-match Bash --matches 'command=sdd-state claim [^\n]* 2 --session'
    not check-transcript tool-arg-match Bash --matches 'command=sdd-state claim [^\n]* 1 --session [^\n]*--takeover'
    command-succeeds 'find ../home/.cache -type f -name progress.md -exec grep -l "^Task 2: branch" {} \; | grep -q .'
}
```

- [ ] **Step 2: Case two**

The same `setup.sh` with two changes: the fixture plan has only Tasks 1 and 2 (delete Task 3 from the heredoc), both independent, and the fixture session claims both (`run_candidate sdd-state claim ... 1 ...` and `... 2 ...`), completing neither, so every remaining task is held and the frontier is empty; `pre()` is case one's, with the identity-line check and a second `claims/task-2` check; the story's message: "Another session of mine holds every claimable task of docs/hyperpowers/plans/parallel.md. Join it with subagent-driven-development from a new worktree and do what the skill says." Acceptance: the agent ran `next`, saw `none reason=held`, posted a `tasks` waiting record, printed the board, handed back, and did not take over. `post()`:

```bash
post() {
    check-transcript skill-called superpowers:subagent-driven-development hyperpowers:subagent-driven-development
    check-transcript tool-arg-match Bash --matches 'command=sdd-state next'
    check-transcript tool-arg-match Bash --matches 'command=sdd-state wait [^\n]*--kind tasks'
    check-transcript tool-arg-match Bash --matches 'command=sdd-state board'
    not check-transcript tool-arg-match Bash --matches 'command=sdd-state claim [^\n]*--takeover'
    command-succeeds 'find ../home/.cache -type f -path "*/waiting/*" -exec grep -l "^kind=tasks" {} \; | grep -q .'
}
```

- [ ] **Step 3: Validate, run against treatment and control**

In the evals repository: `bun run quorum check sdd-held-task-takes-frontier sdd-empty-frontier-posts-and-hands-back`, then `bun run quorum run scenarios/<name> --coding-agent claude` with `SUPERPOWERS_ROOT` at this branch's checkout (treatment) and at `main` before this branch (control, where `register` and `next` do not exist, the setup seeds the plan line by hand, and the scenario is expected to fail on the `next` and `wait` checks), ten runs each where the budget allows and at least three. Record the verdicts under `evals/evidence/2026-10-27-parallel-development/scenario-runs/` and cite them in the evidence README; commit both in the evals repository. `Assumption: the harness home's cache (`../home/.cache`) is where the candidate's `sdd-dir` places the state checkout for the fixture repository, validate via the `pre()` check of case one on the first run, before the scenario is counted.`

- [ ] **Step 4: Record in this repository**

Append the scenario names, the run counts and the evals commit to this plan's ledger; nothing in this repository changes for Task 14 beyond the ledger line and, if the runs surface a skill-text defect, a fix round through the normal loop.
