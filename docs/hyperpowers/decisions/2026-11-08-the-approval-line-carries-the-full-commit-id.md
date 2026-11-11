# The approval line carries the full commit id

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-08-sweep-open-findings-design.md (decision 1)
- Recorded: 2026-11-10; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-09-sweep-open-findings.md removed at finish

## Decision

**The approval line carries the full commit id.** merge-back compares the
whole id, and a shortened id reads as no approval. Rejected: resolving the
seven characters only among the task branch's commits, because a planted
collision on the branch stays possible; an `sdd-state approve` helper,
because it adds a subcommand for a line the controller already writes and
the skill text changes either way. Accepted cost: a ledger in flight at
upgrade re-appends one line per open task.

## What implementation changed

The full-id approval line shipped as decided, and execution tightened its reader in two steps that the plan's correction paragraphs record and that leave the tree at finish. `cmd_merge_back` reads records through `ledger_records` (so a fragment or an unterminated last line never authorizes), takes the newest `Task <N>: approved ` record first, and only then checks its token. A token that is not exactly the repository's id width (`${#sha}`, 40 or 64 hex digits) reads as no approval (`approved=none`), even when an older record holds a valid full id; the spec's "newest record matching the width pattern" would have skipped such a line and let the older one authorize. The id must also end at whitespace or the line's end, so an approval glued to the next append is no approval, where the spec allowed any non-hex character. The `--disambiguate` loop is gone, and the SDD SKILL.md bullet, `example-workflow.md` and the contract needles carry full ids.
