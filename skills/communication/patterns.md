# AI Writing Patterns

The catalogue behind the check table in SKILL.md. Each entry gives the tell, what to do, and one before-and-after pair. Groups A and B are the strongest: one sighting justifies an edit. An entry marked *weak alone* needs company from other tells in the same passage.

Adapted from the humanizer skill (MIT) and from Wikipedia's "Signs of AI writing", maintained by WikiProject AI Cleanup.

## A. Words

### 1. Jargon metaphors

Watch for: blast radius, footgun, yak shaving, spine, backbone, seams, gate (figurative), belt-and-suspenders, bites, time bomb, papers over, the kicker, surface (verb).

Do: write the fact the metaphor stands for (the table in SKILL.md). Keep a word that is part of a name the reader can grep for.

Before: "If you would rather take (b) to limit blast radius, I can have that up faster."

After: "If you would rather take (b) so that only the writer changes, I can have that up faster."

### 2. Load-bearing

Watch for: "the load-bearing assumption", "that comment is load-bearing", "this test is load-bearing".

Do: say what depends on it and what happens if it is false.

Before: "The stateless assumption is load-bearing and one-third verified."

After: "Six of the nine formats move on the stateless assumption, and only three have been checked. If one of the six keeps state, the move is not mechanical."

### 3. Overused words

Watch for: actually, additionally, align with, bolstered, crucial, deep dive, delve, enduring, enhance, garner, highlight (verb), interplay, intricate, key (adjective), landscape (abstract), leverage, meticulous, pivotal, quietly, robust (figurative), showcase, tapestry, testament, underscore (verb), valuable, vibrant.

Do: the plain word, or nothing. A formal word outside this list is not a tell by itself.

Before: "Additionally, the retry default plays a crucial role in why nothing surfaced."

After: "The retry default is also why nothing showed up: the writer's failures were logged at DEBUG."

## B. Staging instead of stating

### 4. Not X but Y

Watch for: not X but Y; not just, not only, not merely X but Y; it's not X, it's Y; X rather than Y for emphasis; X, not Y; the question isn't X, it's Y; the same contrast split across sentences ("This does not mean X. It means Y."); "A is fine. What isn't fine is B."; a clipped negative tail ("..., no guessing").

Problem: the negative half names something nobody claimed, so the positive half sounds larger without adding a claim.

Do: state Y. If the reader said X and X is wrong, correct it in its own sentence first.

Before: "The question isn't retry vs. proper fix for Friday; it's whether billing needs to change this week at all, and it doesn't."

After: "Billing does not need to change this week. Nothing else in the release touches it."

### 5. One-line closers and dramatic fragments

Watch for: a one-sentence paragraph that restates the one before it; "That decides it."; "That distinction matters."; "Read that again."; a sentence after an example that names what it showed; a row of fragments ("No cache. No state. No surprises."); periods between words.

Do: cut a closer that repeats. Keep a short sentence that carries a new fact or consequence. Merge fragments into a sentence with a claim.

Before: "A rushed billing change risks a regression we'd be hotfixing under pressure. That asymmetry decides it."

After: "A rushed billing change risks a regression we'd be hotfixing under pressure, for a bug that costs ten minutes of support time per order."

### 6. Sayings that sound deep

Watch for: the real question is, the real X is, the actual X is, at its core, what really matters, fundamentally, the heart of the matter, X is the Y of Z, X becomes a trap, the language of, the currency of, the architecture of.

Do: replace the saying with the specific claim.

Before: "The real safety net is differential testing."

After: "Run both paths over the same inputs and diff the rows. That catches what the flag window will not."

### 7. Staged run-up

Watch for: Let's dive in, here's what you need to know, without further ado, quick note, Honestly?, Look, Here's the thing, The thing is, Let's be honest, "Summary first, details after", a bare "So:" before the recommendation.

Do: remove the run-up and make the point. "Honestly" inside a sentence is ordinary; the tell is the standalone opener.

Before: "Done with the investigation. Summary first, details after. Root cause: a clock mismatch."

After: "Root cause: a clock mismatch."

### 8. Arguing with no one

Watch for: This isn't mainly about, I'm not saying, To be clear, Don't get me wrong, This is not to say, Some might say... but, A tempting approach would be, One might be tempted to, You might think... but.

Do: remove the defense. Keep an objection the reader raised, or an option they would weigh.

Before: "To be clear, I'm not saying the flag is useless. The flag gives you a rollback."

After: "The flag gives you a rollback."

## C. Rhythm by rule

### 9. Forced triads

Watch for: three adjectives, three parallel examples, or three short facts followed by a lesson, when the meaning has one or two parts.

Do: keep the items the meaning has. Develop the strongest example instead of listing three thin ones.

Before: "The migration is risky, untested, and unproven."

After: "The migration has been checked on three of nine formats."

### 10. Repeated sentence openings

Several sentences in a row start with the same subject. Merge them, change the subject, or start with the action. A deliberate repetition for rhythm stays.

Before: "It reads the row. It checks the key. It writes the batch."

After: "It reads the row, checks the key, and writes the batch."

### 11. Dashes

Rule: no em dashes or en dashes, and no ` -- `, unless the reader's own sample uses them; then match its rate. Replace each with a period, comma, colon, or parentheses. Leave dashes inside code, commands, paths, and URLs.

Before: "The fix — a one-line change — touches 23 importers."

After: "The fix is a one-line change, but 23 modules import the file."

### 12. Stacked qualifiers

Watch for: to be fair, it's also possible, could potentially, might arguably, in some cases it may. *Weak alone.*

Do: one qualifier the facts support. Keep scope statements, safety notices, and real corrections. "Perhaps" and "tends to" are ordinary.

Before: "It could potentially be argued that the retry might have some effect."

After: "The retry may hide the flags."

### 13. Hyphenated pairs after the noun

"The report is high-quality" keeps a hyphen that belongs only before a noun ("a high-quality report"). Drop it after the noun. Dictionary compounds (third-party, cross-functional) keep it. *Weak alone.*

### 14. Passive voice and missing subjects

"The results are preserved automatically." Say who acts when it makes the sentence clearer: "The job preserves the results." *Weak alone.*

## D. Inflation and borrowed authority

### 15. Inflated significance

Watch for: stands as a testament, a pivotal moment, plays a key role, marking the, underscores its importance, reflects a broader, lasting legacy, setting the stage for, evolving landscape; a "Challenges and Outlook" section; "the future looks bright", "a step in the right direction".

Do: keep the fact, drop the significance. End on the last concrete fact.

Before: "Fixing the clock source marks a pivotal step toward a UTC-only pipeline."

After: "Fixing the clock source removes one of the two remaining local-time calls."

### 16. Vague connection

Watch for: associated with, connected to, linked to, tied to, in connection with.

Do: name the relationship. If the source does not say, keep the vague wording rather than invent one.

Before: "The failures are associated with the retry helper."

After: "The retry helper swallowed the failures."

### 17. Shallow -ing riders

Watch for: highlighting, underscoring, emphasizing, ensuring, reflecting, symbolizing, fostering, showcasing, contributing to.

Do: keep the fact; keep the rider only when the source supports it.

Before: "The suite passed, underscoring the stability of the change."

After: "The suite passed."

### 18. Sales language

Watch for: rich (figurative), profound, exemplifies, commitment to, seamless, groundbreaking, renowned, featuring, diverse array, stunning, must-have.

Do: say what the thing is.

Before: "A seamless migration path featuring robust validation."

After: "The migration runs behind a flag and validates rows twice."

### 19. Borrowed authority

Watch for: experts argue, observers have cited, industry best practice, it is widely known; a list of outlets or follower counts standing in for a claim.

Do: name the source and what it said, or cut the claim.

Before: "Best practice says retries belong at the edge."

After: "The retry hides the signal we use to track this race."

### 20. Avoiding is, are, and has

Watch for: serves as, stands as, functions as, represents, boasts, features, offers, refers to.

Do: is, are, has.

Before: "The orchestrator serves as the entry point for every stage."

After: "Every stage calls through the orchestrator."

## E. Formatting by rule

### 21. Bold labels

Watch for: bold on words without a reason; a list where every item opens with a bold label and a colon; a paragraph that opens with a bold sentence as its heading.

Do: remove the bold. Start the sentence with the point. Turn a labeled list into prose when the labels carry no information.

Before: "**4 is the one that worries me.** Stateless is checked on 3 of 9."

After: "Point 4 worries me most. Stateless is checked on 3 of 9."

### 22. Decorative headings

Title Case on every word, emojis or arrows as decoration, a rule between every section, a heading written for effect ("The decision, on one screen"). Use sentence case, drop the decoration, and name what the section holds. A chat message does not need headings.

### 23. Curly quotes

Straight quotes unless the target format curls them. *Weak alone.*

## F. Leftovers from the chat and the draft

### 24. Chatbot residue

Watch for: I hope this helps, Of course!, Certainly!, Great question!, You're absolutely right, Would you like..., "Want me to...?" with no decision behind it, let me know, here is a...

Do: remove the wrapper, keep the content. A question that names a decision the reader must make stays: "Do you want the importer check before the PR or after?"

### 25. Knowledge-limit disclaimers and guesses

Watch for: as of my last update, while specific details are limited, based on available information, not publicly available, likely [grew up, began], it is believed that.

Do: state what the sources do not show, or cut the sentence. Never fill the gap with a plausible guess.

### 26. A heading repeated in the first sentence

Remove the one-line paragraph that restates the heading before the content begins.

### 27. Writing about the document instead of its subject

Watch for: what the text replaced ("was added to replace"); how it was assembled ("compiled from", "anything unconfirmed is flagged"); the layout the reader can see ("the table below compares", "summary first, details after").

Do: describe the subject. Mention a previous version only in a change log or migration guide. Keep a caveat that changes what the reader should do.

Before: "This function was added to replace the O(n^2) loop."

After: "This function uses a hash map for O(1) lookups."

## G. Writing for the wrong reader

### 28. Re-explaining what the reader knows

Watch for: a reply that restates the problem, walks through the diagnosis, and lays out the evidence before the decision; a query or set of numbers included to prove a plan will work; background the other person wrote; the answer in the last line.

Do: lead with the decision. Keep only the reasoning that would change whether the reader agrees, usually one fact they lack and anything they need to act. The full write-up belongs in the ticket or document, not in the reply.

Before: "Yeah, you're right, this works around the issue. The real fix is in `MergeService`: when we move a child under a new parent it should update `pipeline_id` too. We can backfill from the audit log. I checked QA: 123 past merges, only 6 rows wrong. Since `MergeService` is shared, I'd rather open a separate ticket."

After: "Agreed, this is a workaround. The proper fix in `MergeService` widens this past its scope, since it is shared code and needs a backfill. I'd keep this PR as is and open a ticket for the fix. Does that work?"

## When not to act

A person can make any of these choices on purpose. Leave a flagged phrase alone inside a quotation, a title, a proper name, or a passage that discusses the phrase. Salutations and sign-offs predate chatbots. Several tells together are the signal; a reader who judges by one tell does little better than chance.

Keep what carries a person's voice: a specific odd detail, an admitted mixed feeling, a dated reference, a first-person choice they can explain, a real aside or self-correction.
