# Records are mandatory for a branch that has a spec, and the compiler is the only writer

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 10)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**Records are mandatory for a branch that has a spec, and the compiler
is the only writer.** A finish with a spec ends with a records commit or
with the human partner's explicit decision to skip it, recorded in the
hand-back; it never ends by silently dropping the step. The compiler
validates all inputs before its first write, writes idempotently, and
stages last, and every rule in it accepts the state a previous run left
behind (a target it already superseded, a plan it already removed, an
Outcome line it already wrote), so a run after a failure, after a
disposition, or by accident changes nothing it should not. Records are
compiled and staged only after the full test suite has passed, and
committed only after the human partner has seen the complete staged
diff and answered, on every path; a failing suite never leaves an
implemented Outcome or a removed plan behind, and a skip before the
commit is the compiler's `--undo`, which restores every compiler-owned
path to HEAD.

## What implementation changed

Finishing Step 1 runs the compiler only after the suite passes. Step 4 shows the complete staged diff and makes one pathspec commit from a `--paths-file`, with an empty file meaning there is nothing to commit. A skip runs `--undo`, which restores only compiler-owned staged paths, and a never-committed spec is unstaged rather than deleted. The final-gate correction preflights the records directory and exits 2 on any foreign dirty path, so foreign changes never enter the diff or the commit. A supersession target is owned only when HEAD, the index and the working tree agree apart from its Status line, and a target without a Status line is refused. Every rule accepts a previous run's state, so re-runs are idempotent.
