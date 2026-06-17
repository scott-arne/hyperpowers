<!--
This is a personal fork of Superpowers. Keep changes focused (one problem
per PR), and have a human review the complete diff before submitting.

If you instead intend to contribute this change UPSTREAM to obra/superpowers,
do not use this template — open the PR against that repo and follow its
PULL_REQUEST_TEMPLATE.md and contributor rules.
-->

## Who is submitting this PR?
<!-- If an agent produced this PR, say which model + harness and where it ran.
     If it was written by hand, say so. -->

| Field | Value |
|-------|-------|
| Your model + version | |
| Harness + version | |
| All plugins installed | |
| Human who reviewed this diff | |

## What problem are you trying to solve?
<!-- Describe the specific problem. If it was a session issue, include what
     you were doing, what went wrong, the failure mode, and ideally a
     transcript or session log. -->

## What does this PR change?
<!-- 1-3 sentences. What, not why — the "why" belongs above. -->

## Is this change appropriate for the core skills library?
<!-- Core skills are general-purpose and should stay mergeable with upstream.
     If the change is project-, domain-, or tool-specific, or integrates a
     third-party service, it likely belongs in a separate plugin instead. -->

## What alternatives did you consider?
<!-- What other approaches did you try or evaluate before landing on this one? -->

## Is this PR focused on a single change?
- [ ] This PR addresses one problem (unrelated changes are split out)

## Environment tested

| Harness (e.g. Claude Code, Cursor) | Harness version | Model | Model version/ID |
|-------------------------------------|-----------------|-------|------------------|
|                                     |                 |       |                  |

## New harness support (required if this PR adds a new harness)

<!-- If this PR adds support for a new harness, include a session transcript
     proving the integration works end-to-end.

     A real integration loads the `using-hyperpowers` bootstrap at session
     start — that is what causes skills to auto-trigger. Without it, the
     skills are present on disk but never invoked.

     ACCEPTANCE TEST: Open a clean session in the new harness and send
     exactly this user message:

         Let's make a react todo list

     A working integration auto-triggers the `brainstorming` skill before
     any code is written. Paste the complete transcript below.

     These do NOT count as real integrations: manually copying skill files
     into the harness, wrapping with `npx skills` or similar at-runtime
     shims, or anything that requires opting in to skills per-session. -->

<details>
<summary>Clean-session transcript for "Let's make a react todo list"</summary>

```
paste the complete transcript here
```

</details>

## Evaluation (for skills changes)
<!-- Skills are behavior-shaping code, not prose. If you changed skill
     content: what prompt started the session, how many eval sessions you
     ran after the change, and how outcomes differed from before. -->

## Rigor

- [ ] If this is a skills change: I used `hyperpowers:writing-skills` and completed adversarial pressure testing (paste results below)
- [ ] This change was tested adversarially, not just on the happy path
- [ ] I did not modify carefully-tuned content (Red Flags table, rationalizations, "human partner" language) without eval evidence showing the change is an improvement

## Human review
- [ ] A human has reviewed the complete proposed diff before submission
