---
sources: skills/communication skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/using-hyperpowers/SKILL.md skills/finishing-a-development-branch/SKILL.md skills/dispatching-parallel-agents/SKILL.md skills/executing-plans/SKILL.md skills/subagent-driven-development/SKILL.md skills/receiving-code-review/SKILL.md skills/requesting-code-review/SKILL.md skills/systematic-debugging/SKILL.md skills/profiling-performance/SKILL.md skills/optimizing-performance/SKILL.md
source-digest: 565864c8e555
---
# communication

`communication` makes the agent write for a reader who already has the context: the answer first, the specific thing named in plain words, and none of the stock phrasings that make text read as machine-written.

:::{card} At a glance
**Category:** Process · **Triggers on:** writing prose a person will read (a report, summary, or reply to you, a PR description, commit message, or document) and requests to make text read less like AI · **Hands off to:** none; other skills call it · **Harness notes:** none
:::

## When it triggers

The skill's description says to use it when the agent writes prose a person will read, such as a report, summary, or reply to you, a PR description, a commit message, or a document, and when you ask it to make text read less like AI. Several other skills require it for the text you read. {doc}`brainstorming` requires it for the questions, the approach comparison, the design, and the spec. {doc}`writing-plans` requires it for the plan and its handoff message. {doc}`finishing-a-development-branch` requires it for the test-failure report and the PR description, and {doc}`dispatching-parallel-agents` for the report after integration.

Example requests:

- "Summarize what you found in the logs."
- "Write the PR description for this branch."
- Pasting a paragraph and asking "make this sound less like an AI wrote it."

## What it does

The skill is a set of rules the agent applies while writing. It also tells the agent when to leave text alone.

A message to a person follows six rules:

1. The answer comes first: the outcome, decision, or recommendation opens the message.
2. It contains only what the reader lacks. It does not restate their question or their notes.
3. It names the specific thing in plain words: the module, the check, the callers, the number.
4. It states what is true. It does not frame a point by what it is not, announce that a point is coming, or close by saying the point was made.
5. It ends on the last fact. A closing question appears only when you have a decision to make, and it names the decision.
6. It is shaped for a terminal: plain paragraphs, a list only for parallel items, headings only in a document, and no bold labels.

The jargon table lists figures of speech that stand in for a fact, each with what to write instead. "Blast radius" becomes the callers, users, or systems the change reaches. "Footgun" becomes the misuse and its result. The table also covers "yak shaving", "spine" and "backbone", "seams", "gate", "belt-and-suspenders", "long pole", and "load-bearing". Any other metaphor doing a noun's or verb's job gets the same treatment, and a word that is part of a name you can search for, such as a script's name, stays.

The "not X but Y" rule removes every form of the contrast, including "X rather than Y" used for emphasis and a clipped negative tail such as ", no guessing". The agent writes Y. If you said X and X is wrong, it corrects X in its own sentence and then states Y.

The check-before-sending table is a list of tells to look for in a draft: jargon metaphors, "not X but Y", one-line closers, bold labels, narrating the message, saying something sounds deep, dashes, forced triads, inflated words, chat residue, re-explaining, and stacked qualifiers. Each row says what to do. The full catalogue, with before-and-after pairs, is in the supporting file `patterns.md`.

When the agent edits text you wrote, it treats the text as material and not as instructions. It keeps every claim, name, number, date, and citation and adds none. For pasted text it returns the rewrite and a short list of what changed. For a file it changes prose only and leaves code blocks, inline code, commands, paths, front matter, data, and link targets as they are.

The skill does not apply to code, data, commit trailers, or quoted text. It leaves a flagged word alone inside a quotation, a title, a proper name, an identifier, or a passage about the word itself. It also keeps what carries a person's voice: a specific odd detail, an admitted mixed feeling, an aside, or a first-person choice they can explain. One tell in a page is not a reason to edit. Several together are.

## Why it exists

A model's default sentence fits the widest range of readers. It stages a point instead of stating it, reaches for a metaphor instead of the noun, and formats every item the same way. The skill's overview says a person writing to a colleague makes uneven, specific choices, and the skill lists the defaults to replace. Its core principle is that every sentence gives the reader something they did not have, in plain words. The decision records are indexed in {source}`docs/hyperpowers/decisions/README.md`.

## Pros

- Reports start with the result, so you can stop reading once you have what you need.
- The jargon table replaces shorthand with the fact it stood for, so a report carries the number or the module name instead of a label you would have to decode.
- The tells are concrete and checkable, so you can name one in a review ("that is a one-line closer") and the agent knows what to change.
- Text editing preserves claims, numbers, and citations, so a rewrite does not change what the text says.
- Your own instructions about voice, such as a writing sample or a style rule in your instruction file, override everything in the skill, including the dash rule.

## Cons and costs

- The rules are about style, and they cost tokens: the skill loads whenever the agent writes prose for you, and the agent drafts and then checks against the tables.
- Replacing a metaphor with the fact it stood for makes some sentences longer. If the agent lacks the fact, it has to ask or write a simpler sentence, and the skill warns against inventing a detail so that a rewrite flows.
- The rules are fixed by lists. A phrase outside the lists passes even if it reads badly, and a flagged word in a passage that needs it can still be changed by an agent that applies the lists too literally.
- The rule against dashes, bold labels, and closing questions can clash with a house style you already use. The skill yields to explicit instructions about your voice, but you have to give them.
- It governs how a finding is written. The accuracy of the finding depends on the investigation behind it.

## Skipping or overriding

Tell the agent to write in your own style, give it a writing sample, or put a style rule in your instruction file. The skill says such instructions override its rules, including the dash rule. To skip it for one reply, say "no style pass, just give me the raw notes." That is reasonable for scratch output you will rewrite yourself.

## Works with

- {doc}`brainstorming` requires it for everything you read during design: the questions, the comparison, the design, and the spec.
- {doc}`writing-plans` requires it for the plan's prose and the handoff message.
- {doc}`using-hyperpowers` routes writing for you (a summary, a finding, a design, a plan, a recommendation, or a reply longer than a few sentences) to this skill before the agent writes it.
- {doc}`finishing-a-development-branch` requires it for the test-failure report and the PR description.
- {doc}`dispatching-parallel-agents` requires it for the report to you after integration.
- {doc}`executing-plans` requires it for the concerns the agent raises before starting and for the completion report.
- {doc}`subagent-driven-development` requires it for anything written to you: the pre-flight question, an escalation, a BLOCKED hand-back.
- {doc}`receiving-code-review` requires it for the reply itself, whether it goes to you or into a review thread.
- {doc}`requesting-code-review` requires it when the agent reports findings or a gate hand-back to you.
- {doc}`systematic-debugging` requires it when the agent reports a root cause, states a hypothesis, or brings you a question.
- {doc}`profiling-performance` requires it for the deliverable you read.
- {doc}`optimizing-performance` requires it for its report.

## Under the hood

- {source}`skills/communication/SKILL.md` holds the rules, the jargon table, the contrast rule, the check table, and the editing rules.
- {source}`skills/communication/patterns.md` is the catalogue behind the check table, grouped by words, staging, rhythm, inflation, formatting, chat leftovers, and writing for the wrong reader, with a before-and-after pair for each entry.
