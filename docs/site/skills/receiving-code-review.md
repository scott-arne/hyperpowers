---
sources: skills/receiving-code-review skills/requesting-code-review/SKILL.md skills/subagent-driven-development/SKILL.md
source-digest: 71e057ee499b
---
# receiving-code-review

`receiving-code-review` makes the agent check an external reviewer's feedback against the code before acting on it (your own feedback is implemented once the agent understands it), and answer with a technical statement or reasoned pushback in place of agreement.

:::{card} At a glance
**Category:** Review · **Triggers on:** receiving code review feedback, before implementing suggestions, especially when the feedback is unclear or technically questionable · **Hands off to:** {doc}`communication` (the reply itself) · **Harness notes:** none
:::

## When it triggers

The skill's description says to use it when the agent receives code review feedback, before it implements any suggestion, especially when the feedback is unclear or questionable. The skill asks for technical rigor and verification, and rules out both performative agreement and blind implementation.

Example requests:

- "Here are the review comments on the PR. Address them."
- "The reviewer says to remove the legacy code path. Do that."
- "Fix items 1 to 6 from the review."

## What it does

The skill gives the agent a six-step response pattern for review feedback.

1. **Read** the complete feedback without reacting.
2. **Understand** it by restating the requirement in the agent's own words, or asking.
3. **Verify** it against the codebase.
4. **Evaluate** whether it is technically sound for this codebase.
5. **Respond** with a technical acknowledgment or reasoned pushback.
6. **Implement** one item at a time, testing each.

Several rules shape those steps.

**No performative agreement.** The skill forbids "You're absolutely right!", "Great point!", and "Let me implement that now" before verification, and it forbids any expression of thanks. In their place the agent restates the requirement, asks clarifying questions, pushes back if the feedback is wrong, or starts working. When feedback is correct, the reply is a short statement of the fix ("Fixed. [what changed]"), or just the fix.

**Unclear items stop the work.** If any item is unclear, the agent implements nothing yet and asks, because items may be related and partial understanding produces the wrong implementation. With "fix items 1 to 6" where 4 and 5 are unclear, the agent says which items it understands and which it needs explained before it proceeds.

**The source of the feedback matters.** Feedback from you is trusted: the agent implements it once it understands it, still asks if the scope is unclear, and skips straight to action or a technical acknowledgment. Feedback from external reviewers gets five checks before anything is implemented: whether it is correct for this codebase, whether it breaks existing behavior, why the current implementation is the way it is, whether it works on all platforms and versions, and whether the reviewer has the full context. If the suggestion seems wrong, the agent pushes back. If it cannot verify the point, it says so and asks whether to investigate, ask, or proceed. If the suggestion conflicts with your earlier decisions, it stops and discusses that with you first.

**YAGNI check.** When a reviewer asks for a feature to be implemented "properly", the agent searches the codebase for actual usage. If nothing uses it, the agent asks whether to remove it. If it is used, the agent implements it properly.

**Pushing back.** The skill lists when to push back: the suggestion breaks existing functionality, the reviewer lacks context, it violates YAGNI, it is technically incorrect for this stack, compatibility reasons exist, or it conflicts with your architectural decisions. Pushback uses technical reasoning and references to working tests or code, and it involves you if the matter is architectural. If the agent pushed back and was wrong, it states the correction plainly and moves on, with no long apology.

**Implementation order.** For feedback with several items, the agent clarifies anything unclear first. It then fixes blocking issues (breaks and security) first, simple fixes (typos, imports) next, and complex fixes (refactoring, logic) last, testing each fix and checking for regressions.

For GitHub review comments, the skill says to reply in the comment's thread and not as a top-level pull request comment.

## Why it exists

The skill's core principle is that code review needs technical evaluation, with no emotional performance: verify before implementing, ask before assuming, and put technical correctness ahead of social comfort. Its common-mistakes table lists the failures it targets: performative agreement, blind implementation, batching fixes without testing, assuming the reviewer is right, avoiding pushback, partial implementation, and proceeding on something the agent cannot verify. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- A wrong suggestion is caught by the verification step before it changes the code.
- Unclear items are settled up front, so the agent does not build a partial implementation.
- The YAGNI check keeps reviewer-requested additions from growing the codebase when nothing uses them.
- Replies are short technical statements, which are quicker for you to read than agreement and thanks.
- Fixes land one at a time, each tested, so a regression traces to one change.

## Cons and costs

- Verification and the five external-reviewer checks add work before the first edit, even for feedback that turns out to be right.
- The agent stops on any unclear item and waits for you, so a long list of comments can sit idle until you answer.
- Pushback can slow a change down when you only wanted the reviewer's suggestion applied.
- The no-thanks rule produces terse replies, which suits a working thread but may read as cold on a public pull request.

## Skipping or overriding

The skill has no skip option, and its forbidden-response rules apply to feedback from you as well. What it does vary is trust. Your own feedback is implemented after the agent understands it, while an external reviewer's feedback is checked first. If the agent pushes back and you still want the change, say so: the skill says the agent involves you when a suggestion conflicts with your decisions.

## Works with

- {doc}`requesting-code-review` is where this skill comes from: its step 3 names this skill as the required sub-skill for acting on feedback and treats findings as claims to evaluate.
- {doc}`subagent-driven-development` has the fixing implementer verify each task-reviewer finding with this skill. A finding is declined only as refuted or corrected, with file and line evidence.
- {doc}`communication` is the required sub-skill for the reply, whether it goes to you or into a review thread.

## Under the hood

{source}`skills/receiving-code-review/SKILL.md` is the whole skill. It has no supporting files or scripts.
