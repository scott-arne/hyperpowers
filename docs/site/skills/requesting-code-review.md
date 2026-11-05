---
sources: skills/requesting-code-review skills/subagent-driven-development/SKILL.md skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/executing-plans/SKILL.md skills/receiving-code-review/SKILL.md skills/optimizing-performance/SKILL.md
source-digest: cbce94763be8
---
# requesting-code-review

`requesting-code-review` has the agent dispatch a reviewer subagent over an exact range of commits, then act on what comes back, and under Claude Code it adds an optional second review from Codex.

:::{card} At a glance
**Category:** Review · **Triggers on:** completing tasks, implementing major features, or before merging, to verify work meets requirements · **Hands off to:** {doc}`receiving-code-review` (acting on the findings) and {doc}`communication` (reporting findings or a gate hand-back) · **Harness notes:** Codex review gate: Claude Code only; it is skipped with a short notice when Codex is absent
:::

## When it triggers

The skill's description says to use it when the agent completes tasks, implements a major feature, or is about to merge, to check that the work meets its requirements. Its own list marks three moments as mandatory: after each task in {doc}`subagent-driven-development`, after a major feature, and before a merge to main. It calls three more optional but valuable: when stuck (a fresh perspective), before refactoring (a baseline check), and after fixing a complex bug.

Example requests:

- "Review this branch before I merge it."
- "I just finished the payment refactor. Get it reviewed."
- "Ask for a review of the last three commits against the plan."

## What it does

1. **Pick the range.** The agent records the head commit and chooses a base for the scope under review. For a whole branch the base is the branch point (`git merge-base origin/main HEAD`). For one task it is the commit recorded before the task began. The skill says never to use `HEAD~1`, because that keeps only the last commit of a multi-commit change.
2. **Dispatch the reviewer.** The agent starts a `general-purpose` subagent from the template in `code-reviewer.md`, filling in a description of what was built, the plan or requirements, and the two commits. The reviewer gets this context and never the agent's session history.
3. **Read the review.** The template asks the reviewer for strengths, then issues sorted into Critical, Important, and Minor, each with a file and line, what is wrong, why it matters, and a fix, and finally a verdict: ready to merge, no, or with fixes. The template requires proof for Critical and Important findings (the snippet, a failure scenario, and why existing guards do not catch it) and tells the reviewer to downgrade or drop a finding it cannot prove. It also says zero findings is a valid review.
4. **Act on the feedback.** The agent uses {doc}`receiving-code-review` to evaluate the findings, which the skill describes as claims to check and not instructions to carry out. It fixes Critical issues immediately, fixes Important issues before going on, notes Minor issues for later, and pushes back with reasoning when the reviewer is wrong.
5. **Codex review gate (Claude Code only).** After acting on the Claude reviewer's feedback and before declaring the review complete, the agent runs a Codex review over the same range, following `codex-review-gate.md`.

### The Codex gate

The gate first runs a preflight that reports whether the `codex-plugin-cc` plugin is usable. If Codex is available, the agent gives it the same plan or requirements context the Claude reviewer had. Codex's first review splits into several narrower reviews, called lenses, over one shared dossier of the change. The lenses for a code review are correctness, contracts and integration, and tests and evidence. The agent resolves blocking findings in a fix-and-re-review loop that ends when a normalized result says approved, or when a round ceiling is reached and the leftovers are handed back to you.

Codex severities map onto the skill's own vocabulary:

| Codex | Review skill | Blocks? |
|---|---|---|
| critical | Critical | yes |
| high | Important | yes |
| medium or low | Minor | no |

Blocking means Critical plus Important. Minor findings are noted and not fixed in the loop. An incomplete Codex result is never treated as approval: a script normalizes each captured result to approved, blocking, or incomplete, and only approved counts. After any fix that Codex's findings triggered, the agent re-runs the Claude code reviewer before running Codex again.

When Codex is absent, the agent tells you once with a notice that names a status (`not-installed`, `not-ready`, `stale-broker`, or `preflight-error`), records the skipped review in a ledger, and finishes the review without it. For the not-installed case the notice includes the plugin install commands. The gate never blocks completion; at worst it is skipped.

## Why it exists

The skill's core principle is to review early and review often, so that issues are caught before they cascade into later work. Its rationalizations table gives two reasons for the shape of the review. An agent that reviews the diff inline spends the context window it needs to keep working, so the diff and the evaluation live in a subagent and only the findings return. And a reviewer that reads the agent's whole session reviews the thought process, so it receives crafted context and not history. The Codex gate adds a second reviewer from a different system after the first pass. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- The reviewer judges the work product from a fresh context, with no view of the agent's reasoning.
- An explicit base commit keeps the review on the whole change and not just the last commit.
- Proof requirements and the instruction to downgrade unprovable findings keep severity honest, and the template says zero findings is acceptable.
- The optional Codex gate brings a second reviewer and a mechanical rule for what counts as approval.
- A missing or unready Codex costs you one notice and the review still completes.

## Cons and costs

- A review adds a subagent run to every task or feature it covers, and the Codex gate adds a longer one, with a fix-and-re-review loop when it finds blockers.
- The Codex gate depends on a third-party plugin, and it has to run outside the Bash sandbox, so a sandboxed shell cannot run it.
- The gate runs in Claude Code only. In another harness it is skipped silently, with no notice.
- Findings can send the agent back into fixes, so a review that was meant to end the task can lengthen it.
- The reviewer sees only the range and the context the agent writes down, so a vague description or missing requirements weakens the review.

## Skipping or overriding

The skill's red flags say never to skip review because "it's simple" and never to ignore Critical issues. The skill gives you no option to switch review off. The Codex gate is skipped only when Codex is absent, and then the agent tells you with a notice and finishes the review without it. When a finding is wrong, the agent pushes back with technical reasoning, shows code or tests that prove the work, or asks the reviewer for clarification.

## Works with

- {doc}`subagent-driven-development` lists a review as mandatory after each task, uses this skill's `code-reviewer.md` template for its final whole-branch reviewer, and runs the same Codex gate per task and at the end.
- {doc}`executing-plans` tells the agent to use this skill after each task or at natural checkpoints.
- {doc}`brainstorming` runs the Codex review gate over the written spec (a document review, using this skill's gate files) before you review the spec.
- {doc}`writing-plans` runs the same gate over the written plan before presenting it to you.
- {doc}`receiving-code-review` is the required sub-skill for acting on the findings.
- {doc}`communication` is the required sub-skill for reporting findings or a gate hand-back to you.
- `optimizing-performance` names this skill and the Codex gate as required parts of its workflow.

## Under the hood

{source}`skills/requesting-code-review/SKILL.md` is the skill itself. The rest of the directory is the reviewer template and the Codex gate, which other skills reuse.

- {source}`skills/requesting-code-review/code-reviewer.md` is the reviewer subagent's prompt template, with the output format and the read-only clause every reviewer shares ({source}`skills/requesting-code-review/reviewer-read-only-clause.md`).
- {source}`skills/requesting-code-review/codex-review-gate.md` is the gate's entry point: it lists the section files and the route each caller reads.
- The section files hold the gate's steps. {source}`skills/requesting-code-review/gate-preflight.md` covers availability and the no-Codex notice, {source}`skills/requesting-code-review/gate-findings.md` the severity mapping and the completion check, and {source}`skills/requesting-code-review/gate-fix-loop.md` the fix-and-re-review loop and hand-back. The others cover setup, lenses, output schema, document and code recipes, and the review sweep.
- {source}`skills/requesting-code-review/scripts/codex-preflight` reports whether a Codex review can run, and {source}`skills/requesting-code-review/scripts/verdict-normalize` turns a captured result into approved, blocking, or incomplete. The `scripts` directory holds the other helpers for the base check, round counting, waiting on jobs, and the ledger of skipped reviews.
