**Document review prompt templates.** Round 1 composes these through the lens fan-out in gate-lenses.md; re-review rounds (2+) use them as written here, after the round-aware preamble.

**Spec documents** — use `task`, read-only (no `--write`):

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <SPEC_REVIEW_PROMPT_PATH>
```

`<SPEC_REVIEW_PROMPT_PATH>` should contain a short prompt like this. Copy the
Required document-review output block from gate-output-schema.md into the prompt so Codex has the
schema in its own context.

```markdown
Review the spec document at <SPEC_ABSOLUTE_PATH> for completeness, internal consistency, ambiguity, and scope. If original user requirements or approved design notes are available, use them as context: <APPROVED_DESIGN_CONTEXT_PATH>. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything. Return exactly the Required document-review output from the output shape included below.
```

**Plan documents** — use `task`, read-only (no `--write`), and provide both the
source spec and the plan:

```bash
node "$CODEX_PATH/scripts/codex-companion.mjs" task --fresh --prompt-file <PLAN_REVIEW_PROMPT_PATH>
```

`<PLAN_REVIEW_PROMPT_PATH>` should contain a short prompt like this. Copy the
Required document-review output block from gate-output-schema.md into the prompt so Codex has the
schema in its own context.

```markdown
Review the implementation plan at <PLAN_ABSOLUTE_PATH> against the source spec at <SPEC_ABSOLUTE_PATH>. Check feasibility, task sizing, missing steps, ordering, type/signature consistency, and spec coverage. You are a stateless reviewer for this request only; do not load or read skill bootstraps or skills. Do not edit anything. Return exactly the Required document-review output from the output shape included below.
```

**Round-1 Algorithm Assessment (plan gate only).** When BOTH hold — this is
round 1 of the plan gate, AND the plan contains material algorithmic or
data-structure choices (sorting/searching, graph traversal, caching strategies,
concurrency schemes, index/layout choices — not glue code or CRUD wiring) —
append this to the plan prompt:

    Additionally, assess the plan's material algorithm and data-structure choices.
    For each one: is it the right choice for the stated constraints and data
    scale? If not, propose exactly one alternative with justification (complexity,
    tradeoffs, why it wins here). Return this block after the Required output:

    Algorithm Assessment (round 1 only):
    - choice: <algorithm/structure as planned>
      verdict: appropriate | alternative-suggested
      alternative: <name, or None>
      justification: ...

Plans with no material algorithmic or data-structure choices omit this section entirely.
Algorithm suggestions are **advisory input to the controller's decision** —
they do not map onto the Critical/Important severity ladder (§4) and never
drive the fix loop (§5). If Codex separately judges an algorithm choice to be
a genuine blocking defect, that is a normal blocking finding, unchanged.
