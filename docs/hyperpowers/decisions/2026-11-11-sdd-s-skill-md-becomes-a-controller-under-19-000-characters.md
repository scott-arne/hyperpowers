# SDD's SKILL.md becomes a controller under 19,000 characters, and its step text moves into five sibling files

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-11-compaction-reread-notice-design.md (decision 7)
- Recorded: 2026-11-14; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-11-compaction-reread-notice.md removed at finish
- Supersedes: docs/hyperpowers/decisions/2026-11-03-fix-truncation-with-a-re-read-paragraph.md

## Decision

**SDD's SKILL.md becomes a controller under 19,000 characters, and its
step text moves into five sibling files.** At the 100,000-token
window released 6.18.1 failed 10 of 10 runs of `sdd-compaction-reread`
with Claude Code's "Autocompact is thrashing" stop, and so did the notice
arm: a full re-read of the 76,445-character skill (41,751 when 6.16.2
measured the paragraph) costs about 27,000 tokens, needs two Reads, and
puts the context back at the threshold. A controller that fits Claude
Code's 20,000-character re-attachment comes back whole, so only the
current step's file is re-read. The human partner set the 100,000-token
floor as the window SDD must work at (2026-11-12). Rejected: phase
modules with the current phase recorded in the ledger, which add state
that can go stale; a short recovery document holding the rules the cut
drops, a second copy that drifts and summarizes 56,000 characters of
loop rules lossily; re-reading only the text past the cut, about 15,000
tokens and growing with every addition to the skill, where offline size
checks cap the controller and one step file near 10,000 tokens; supporting only windows of 200,000
or more.
Supersedes: docs/hyperpowers/decisions/2026-11-03-fix-truncation-with-a-re-read-paragraph.md

## What implementation changed

`skills/subagent-driven-development/SKILL.md` became a controller, and its step text moved into `setup.md`, `task-loop.md`, `review-and-complete.md`, `fix-loop.md` and `final-and-finish.md`. The new `tests/sdd/test-sdd-layout.sh` caps each step file under 17,000 characters, requires SKILL.md to link each one, and resolves every relative link. `tests/sdd/test-sdd-contract.sh` and `tests/codex-review-gate/test-gate-contract.sh` were repointed at the split files. The plan's Task 8 correction (2026-11-13) tied to decision 8 also changed the layout.
