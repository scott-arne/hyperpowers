### 3. Review the task

Part of [SKILL.md](SKILL.md); the rules there hold in this step.

Per-task reviews are task-scoped gates. The broad review happens once, at the
final whole-branch review. Never skip the task review, and never accept a
report missing either verdict — spec compliance AND task quality are both
required. Implementer self-review never replaces the task review; both are
needed. Note the task's effective risk tier as you go (see Risk Tiers
in [SKILL.md](SKILL.md)) — the Claude task review always runs, but the tier decides whether
step 4's per-task Codex gate does.

- Hand the reviewer its diff as a file: run this skill's
  `scripts/review-package PLAN_FILE BASE HEAD` — it prints
  `wrote <path>: <N> commit(s), <N> bytes`, so take the path from that line
  and pass it to the reviewer (or, without bash: `git log --oneline`,
  `git diff --stat`, and `git diff -U10` for the range, redirected to one
  uniquely named file). The output never enters your own context, and the reviewer sees
  the commit list, stat summary, and full diff with context in one Read
  call. Use the BASE you recorded before dispatching the implementer —
  never `HEAD~1`, which silently truncates multi-commit tasks. Never
  dispatch a task reviewer without a diff file.
- **Reviewer inputs:** the task reviewer gets three paths — the same brief
  file, the report file, and the review package — plus the global
  constraints that bind the task. Write those global constraints to a small
  file alongside the brief and report: the per-task Codex gate takes the
  same file as its global-constraints handoff.
- The global-constraints block you hand the reviewer is its attention
  lens. Copy the binding requirements verbatim from the plan's Global
  Constraints section or the spec: exact values, exact formats, and the
  stated relationships between components ("same layout as X", "matches
  Y"). The reviewer's template already carries the process rules (YAGNI,
  test hygiene, review method) — the constraints block is for what THIS
  project's spec demands.
- Do not add open-ended directives like "check all uses" or "run race tests
  if useful" without a concrete, task-specific reason
- Do not ask a reviewer to re-run tests the implementer already ran on the
  same code — the implementer's report carries the test evidence
- Do not pre-judge findings for the reviewer — never instruct a reviewer to
  ignore or not flag a specific issue. If you believe a finding would be a
  false positive, let the reviewer raise it and adjudicate it in the review
  loop. If the prompt you are writing contains "do not flag," "don't treat X
  as a defect," "at most Minor," or "the plan chose" — stop: you are
  pre-judging, usually to spare yourself a review loop. When the plan supplies
  example code, weaknesses in that code are fair review targets — the example
  was a starting point, not evidence that its weaknesses were chosen.
The task reviewer may report "⚠️ Cannot verify from diff" items — requirements
that live in unchanged code or span tasks. These do not block the rest of the
review, but you must resolve each one yourself before marking the task
complete: you hold the plan and cross-task context the reviewer
lacks. If you confirm an item is a real gap, treat it as a failed spec
review — it enters the fix loop with the other findings.

Template: [task-reviewer-prompt.md](task-reviewer-prompt.md)

**Codex Review Gate (Claude Code only).** When running under Claude Code, add
a Codex **code** review gate at two points — here, per task, and once more
at the final whole-branch review — following
[../requesting-code-review/codex-review-gate.md](../requesting-code-review/codex-review-gate.md).
Probe once per skill run and reuse the result; if Codex is absent, emit the
no-Codex notice once and run both gates as no-ops.

- **Per task:** after the task reviewer approves (spec ✅ and quality approved) and
  before marking the task complete, run the gate (standard/high effective tiers; an effective-low task skips it per Risk Tiers in [SKILL.md](SKILL.md), recording the tier-skip event instead) using the per-task code recipe
  with `--base <the task BASE you recorded before dispatching the implementer>`.
  Provide the task brief path, implementer report path, review-package path, and
  the global-constraints file you wrote in step 3. The gate's dossier `--adjudications` inputs carry the plan's `**Spec:**` file path beside any spec-gate ledger, so the reviewer is handed the binding authority instead of inferring it.
- **Rounds are shared, not stacked.** Blocking findings from this gate enter
  the five-round loop in [fix-loop.md](fix-loop.md), at the next round number — the gate has no
  separate Codex ceiling of its own. The task's fix-round budget is five,
  shared across Claude-reviewer rounds and Codex-gate rounds. Three mechanics
  keep that single budget honest:

  1. **One `GATE_DIR` for this task's whole gate lifecycle.** Create it at
     the task's first gate invocation and reuse that same dir for every
     Codex re-round of this task — the gate doc's §3 contract, "Use one
     `GATE_DIR` for the whole gate." `gate-round`'s counter lives in that
     dir, so it counts exactly this task's gate rounds and nothing else.
     When the `GATE_DIR` is first created, record it in the progress ledger
     as one line `Task N gate dir: <path>`; on resume (or any later Codex
     re-round), reuse the ledgered path instead of creating a new one; if
     the ledgered dir no longer exists (cache purged), treat the task's
     prior gate rounds as unknown and fail closed: do not assume zero —
     reconstruct the consumed-round count from the ledger's fix-round
     entries and, if gate rounds cannot be established, surface via BLOCKED
     rather than restarting the count.
  2. **Let the counter do the arithmetic.** `gate-round` compares its LOCAL
     count — gate rounds only, monotonic within the `GATE_DIR` — against a
     ceiling, so the ceiling must leave gate rounds out; they are already in
     that count. Pass `--consumed <NON-gate fix rounds this task has consumed
     so far>` (all fix/re-review rounds, whatever the finding's origin — the
     gate's own invocation rounds are excluded only because `gate-round`'s
     counter already holds them) and the script derives the ceiling from the
     shared five-round cap itself. Recompute the consumed count at each call:
     non-gate rounds may land between gate rounds. Do not hand-compute
     `--ceiling` for a task gate — that is how twenty measured task gates
     recorded ceilings of 1, 2, 6, and 7, two of which the cap makes
     impossible. `--consumed` cannot express them.
  3. **A spent cap is BLOCKED, not a gate round.** When the task's consumed
     rounds already total five, `--consumed 5` yields a ceiling of zero and
     the gate backstops on its first call. That is the fail-closed floor, not
     the intended path: check before calling, and when the cap is spent follow
     the breaker in [fix-loop.md](fix-loop.md) and surface the task as BLOCKED rather than spending a
     gate invocation to learn it.

  The invariant in one line: **local gate rounds + non-gate fix rounds ≤ 5**,
  enforced because `gate-round` blocks (verdict `backstop`) the moment its
  local count would exceed the ceiling. Count every round the
  gate runs against the task's shared budget — each gate round consumes one
  of the five, exactly like a reviewer round. After a Codex-triggered fix,
  the scoped re-review verifies it; the gate re-runs only once that
  re-review verdicts every finding ADDRESSED or DECLINED.

### 5. Complete the task

When the review comes back clean — the task reviewer approved, every
fix-loop finding is addressed or declined, and the per-task Codex gate
approved or was skipped by tier — in this order, each step idempotent on a
resume:

- Append `Task <N>: approved <full id>` with the head the reviewers saw,
  written with `git rev-parse <head>` (every later approval of the same task
  appends a new line; the newest is what merges). merge-back compares the
  whole id, so a shortened id reads as no approval.
- Merge back: `scripts/sdd-state merge-back PLAN_FILE N --session <sid> --commit <sha>`.
  `merged` continues (`already=1` on a resume means the ref was moved
  before the crash). `conflict paths=<list>`: merge the integration branch
  into the task branch in your worktree (`git merge <integration>`), resolve
  through one implementer dispatch whose brief names the paths and both
  sides, re-run the task reviewer over the resolution and the task gate's
  re-review lens, append the new `approved` line, and retry. `checked-out`
  names a worktree or `lease:<sid>`: a final train holds the branch; post a
  `tasks` record and retry after it ends, or ask your human partner to move
  the checkout. `not-approved approved=<sha7|none>` means your bookkeeping
  is behind: the commit you passed is not the task's newest `approved` line,
  so append the `approved` line for the head the reviewers saw (or pass that
  head) and retry. `blocked waiting=<list>` (exit 7) means an amendment put a
  prerequisite under your claim after you took it, and merge-back enforces
  the edge: leave the `approved` line as it is, and never write a completion
  line for a task this session did not complete. Run `next` and take what it
  offers; on `own-blocked`, post, print the board and hand back as the
  `own-blocked` text in [task-loop.md](task-loop.md) says. Retry merge-back once every waiting task has
  its completion line, or after your human partner removes the edge.
  `not-holder owner=<sid>` (exit 4)
  means the claim is no longer yours (after a takeover your human partner
  granted, that session holds it): stop and hand back with the line; never
  repair the ledger or take the claim back.
- Detach at the merged head and drop the task branch:
  `git switch --detach <merged head>` then `git branch -d <task branch>`
  (its commits are on the integration branch now; a missing branch on a
  resume is fine). If `-d` refuses, the branch holds commits that were never
  approved or merged: keep it, do not force the delete, and hand back to
  your human partner with git's output.
- Complete the task: run `scripts/sdd-state complete PLAN_FILE N
  --commits <base7>..<head7>` and repeat it until it prints `status=complete`
  (`busy` and `error` are retried; `unknown-task` means the number is not a
  heading in the plan, `no-workspace` that the ledger is gone, and a usage
  error that the arguments are wrong: each of those stops you, not the loop).
  Its `snapshot=` is the completion's durable record.
- Mark the todo complete (where you keep todos), and run `next`.

A task whose ledger has a `merged` line and no completion line is resumed
at the completion line, never redispatched.

