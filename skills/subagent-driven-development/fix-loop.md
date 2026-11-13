### 4. The fix loop

Part of [SKILL.md](SKILL.md); the rules there hold in this step.

The loop triggers when the review reports spec ❌, any Critical or Important
finding, a ⚠️ item you confirmed as a real gap, or a blocking finding from
the per-task Codex gate in [review-and-complete.md](review-and-complete.md).

Task-reviewer findings are claims too. The fixing implementer verifies
each finding against the code before fixing it
(hyperpowers:receiving-code-review); a finding is declined only as
refuted or corrected with file:line evidence, which the controller
records in the ledger; a confirmed finding is fixed or carried open; a
finding nobody can settle stays open and counts against the round cap.

Before the loop starts, two routes leave it immediately:

- Record Minor findings in the progress ledger as you go
  (`Task <N>: minor (deferred): <one-liner>`), and point the final
  whole-branch review at that list so it can triage which must be fixed
  before merge. A roll-up nobody reads is a silent discard. Minor findings
  never enter the loop.
- A finding labeled plan-mandated — or any finding that conflicts with what
  the plan's text requires — is your human partner's decision: present the
  finding and the plan text beside it and ask which governs. Do not dismiss
  the finding because the plan mandates it, and do not dispatch a fix that
  contradicts the plan without asking.

Everything else enters the loop — the Claude task reviewer's blocking
findings and the per-task Codex gate's blocking findings alike. They are ONE
loop with ONE shared cap of **five rounds per task**: the gate does not run
a count of its own. A fix round is one fix dispatch — or one
controller-applied de-minimis fix — plus one scoped re-review.

**Rounds 1-3 — the same model, carrying the task's record.** Where the Agent
tool offers `run_in_background` (Claude Code outside fork mode), dispatch a
fresh implementer in the foreground (`run_in_background: false`) with the
brief path, the report-file path, and the open findings verbatim, on the
original implementer's model (the `model` in its ledger identity line);
tell it a prior implementer did the
task and the report file records what it did and tried. A foreground
dispatch keeps your turn open until the fix returns, so a fix round on
Claude Code dispatches a fresh foreground implementer; a SendMessage resume
is for harnesses without the option, Claude Code's fork mode among them. On
those harnesses, resume the original
implementer with the findings verbatim: its context is intact. If the
harness cannot message a live subagent either, dispatch a fresh implementer
with the brief path, the report-file path, and the findings; the report file
is the persistent memory either way.

**Rounds 4-5 — dispatch a fresh takeover implementer on a more capable
model** (per Model Selection), with the brief path, the report-file path,
the open findings, and this framing: "A prior implementer attempted this
task [N] times; you own it now. Read the report file for what was tried." A
loop that survives three rounds usually means the same model cannot see
its own problem: the takeover brings a more capable one.

**Every round, either way:** the implementer fixes, re-runs the tests
covering the amended code, appends its fix report to the same report file,
and returns the short contract. Before re-dispatching the reviewer, confirm
the fix report contains the covering tests, the command run, and the
output; dispatch the re-review once all three are present. That
precondition covers the findings the round fixed; a round that declines
every finding is defined below. Name the covering test files in the fix
message — a one-line fix does not need the whole suite. The per-task loop
gives a fix round to an implementer rather than a fixer, so it never uses
[fix-subagent-prompt.md](fix-subagent-prompt.md) — that template belongs to
the final review's one fix wave.

**The re-review is scoped.** Run `scripts/review-package PLAN_FILE FIX_BASE HEAD`
where FIX_BASE is the head the previous review saw, and dispatch
[re-review-prompt.md](re-review-prompt.md) with the findings list, the
brief, the report file, and the printed diff path. The re-reviewer verdicts
each finding ADDRESSED, NOT ADDRESSED, or DECLINED — a refuted or corrected
finding whose file:line evidence the re-reviewer has confirmed; an unconfirmed
decline stays NOT ADDRESSED — and flags new breakage in the fix diff only. The
controller records each DECLINED finding in the ledger with its evidence. New
Critical/Important breakage in the fix diff joins the open findings list.
Out-of-scope observations go to the ledger as deferred minors — they never
extend the loop. Every round in this loop ends with the scoped re-review —
never a full task-reviewer re-run, whatever the finding's origin.

**A round that declines every finding changes no code.** There is no fix
diff and no covering test to confirm; the implementer's report is the
artifact, carrying for each finding the refuted or corrected evidence at
file:line. Skip `scripts/review-package` for that round — its range is
empty — and dispatch the scoped re-review with the findings list, the brief,
the report, and the previous review's package path, so the re-reviewer
verdicts each finding DECLINED or NOT ADDRESSED from the evidence alone. The
covering-tests precondition applies only to findings that were fixed. Record
the round as `(0 addressed, <Y> declined, <Z> open)`; a NOT ADDRESSED verdict
keeps that finding open and the round counts toward the cap as usual.

**After each round,** append to the ledger:
`Task <N>: fix round <R>/5 (<X> addressed, <Y> declined, <Z> open — <finding one-liners>; commits <a7>..<b7>)`

Never fix findings yourself in the controller session — your context stays
clean for coordination, and controller fixes skip review. One narrow
exception: a fix fully specified by the finding itself — exact file, exact
lines, exact replacement, no judgment left — touching at most 3 lines in
one file with no new logic, may be controller-applied — one finding per
reach; a round holding two such findings is not de minimis. The exception
waives nothing else: it consumes a fix round and ends in the same scoped
re-review; the controller applies the edit and runs the fix's covering
command FIRST — a failure means the fix was not de minimis: revert the
edit, spend no round, and go back to the round's own rule — then commits
the verified fix (the re-review packages committed diffs — an
uncommitted fix hands it nothing) and appends the fix report — the
command, its output, and a diff summary — to the task's report file
itself, exactly as an implementer would. Its ledger line keeps the
fix-round schema with the marker inside it:
`Task <N>: fix round <R>/5 controller-applied (de minimis) (<X> addressed, <Y> declined, <Z> open — <finding one-liners>; commits <a7>..<b7>)`.
Reaching for it twice in the same task means the findings are not de
minimis — go back to the round's own rule: hand the findings to an
implementer at rounds 1-3, dispatch the takeover at rounds 4-5.

When the re-review leaves no finding open, go to the per-task Codex gate in [review-and-complete.md](review-and-complete.md), or, for an effective-low task, to step 5 there.

**The breaker.** When round 5's re-review — or a per-task Codex gate at the
spent cap — still leaves blocking findings open, stop dispatching. The task
does not silently continue and nothing is parked on your own authority:
surface the open findings to your human partner as BLOCKED, each with the
rounds already spent, what was tried, and the evidence. Ledger it:
`Task <N>: BLOCKED at cap — <finding one-liners>`. They decide what happens
next.

