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
