# Decision Brief Before the Selector — Eval Evidence

Date: 2026-08-28
Skills changed: `skills/brainstorming/SKILL.md` (new "Deciding Together"
section plus a pointer from the clarifying-questions bullet),
`skills/subagent-driven-development/SKILL.md` (the plan-scan batched question
now cites that section).
Scenario: `brainstorming-decision-brief-precedes-selector` (evals repo).

## The defect

`AskUserQuestion` renders each option as a ~5-word label plus one line of
description. When the options differ only in preference that is enough. When
they differ in what happens afterward — an interface, a stored format, a
default, work that would have to be redone — it is not, and the human is
choosing between labels with the reasoning nowhere in view.

The skill already carried the right instruction at
`brainstorming/SKILL.md:218` ("Present options conversationally with your
recommendation and reasoning"), but scoped to the architectural path's
**Exploring approaches** step. The clarifying-question loop that fires on
*every* path said only "Prefer multiple choice questions when possible", which
routes consequential decisions straight into the widget.

## RED — the failure reproduces

Fixture: a cheminformatics library whose `pairwise_distance()` is plain
Euclidean over raw descriptor columns. The brief asks for normalization and
mentions in passing that the function is called once per assay batch and the
clusters are compared across batches. That detail creates a real fork —
per-call statistics silently invalidate the cross-batch comparison — whose
consequences (API surface, cross-call reproducibility, which mistake stays
reachable by default) do not survive compression into option labels.

Live gauntlet, `claude-vertex` pinned to `claude-sonnet-5`, three runs against
the unamended skill: **0/3 pass**. All four deterministic checks passed in
every run — the skill fired, the widget was used, the bounded path held — and
all three failed the same three acceptance criteria in the same way:

- The pre-widget chat message described the hazard of *one* branch only, never
  both options with their respective consequences.
- No recommendation reached chat. In all three runs `(Recommended)` appeared
  only inside a widget option label, which the story explicitly excludes.

## Form selection — the prohibition arm is inert

`writing-skills`' "Match the Form to the Failure" classifies this as a
**shaping** failure (the agent complies; the output has the wrong shape), not a
discipline failure, and predicts prohibitions backfire there. The original
design carried two Red Flags rows. They were tested rather than assumed.

Micro-test, sonnet, fresh context per rep, `AskUserQuestion` simulated via
`--append-system-prompt`. Only reps whose SessionStart bootstrap actually
loaded are counted:

| Arm | n | Comparison in chat | Recommendation in chat | Widget kept |
|---|---|---|---|---|
| Control (no guidance) | 5 | 1 | 1 | 4 |
| Recipe + 2 Red Flags rows | 5 | 1 | 0 | 4 |
| Recipe v1 | 4 | 3 | 2 | 1 |
| Recipe v2 | 5 | 0 | 0 | 5 |
| Recipe v3 | 5 | 1 | ~0 | 5 |
| Recipe v4 (shipped) | 5 | 0 | 0 | 5 |

The prohibition arm is indistinguishable from no guidance and produced fewer
recommendations than the control. **The two Red Flags rows were dropped from
the design on this evidence.**

## A micro-test artifact worth recording

In the simulated widget, no rep in any arm ever produced both the comparison
and the widget: every rep that wrote a real comparison had abandoned the
widget, and every rep that used the widget wrote a one-line preamble. Four
wording variants failed to break that coupling, which looked like a hard
behavioral constraint.

It was not. The simulation asks the agent to emit the call as a fenced JSON
block "then stop your turn", which makes the question one indivisible
deliverable. With the real `AskUserQuestion` tool the agent writes ordinary
chat text above the tool call as a matter of course — every control run did —
so the coupling is an artifact of the harness, not of the model. Wording
picked in that simulation is only weak evidence; the live runs are the
measurement that counts. Recipe v4 shipped despite scoring 0/5 there.

## GREEN — the amendment

Three live runs against the amended skill, same scenario, model, and fixture:
**3/3 pass**, all seven acceptance criteria met in each. Distributions are
fully separated (control 0/3, treatment 3/3).

The passing shape, from the Gauntlet-Agent's own summary: "before the key
'stats scope' selection widget, wrote a chat message laying out both options
with per-option consequences (API/signature impact and cross-batch
comparability) plus an explicit recommendation with a reason. It then used the
widget for the choice."

Run directories, preserved under `evals/results/`:

| Arm | Run ID | Verdict |
|---|---|---|
| Control | `…-20260828T232759Z-96f2` | fail |
| Control | `…-20260828T234104Z-4794` | fail |
| Control | `…-20260828T234453Z-c634` | fail |
| Treatment | `…-20260828T233322Z-540d` | pass |
| Treatment | `…-20260828T234106Z-f8a9` | pass |
| Treatment | `…-20260828T234459Z-0bff` | pass |

**Residual, not fixed:** in one treatment run the agent's *first* widget (a
lower-stakes question) carried no chat brief, and the Gauntlet-Agent recorded
it as an observation rather than a criterion failure. The guidance is keyed to
options that "differ in what happens afterward", so a preference question
legitimately skips the brief — but whether the agent is applying that
predicate or merely briefing the last question is not something these runs
distinguish.

## Two defects found along the way

- **Opus does not auto-trigger `hyperpowers:brainstorming` on this task.**
  0/5 under `claude -p` with the bootstrap confirmed loaded, against sonnet's
  5/5. This is why the live runs pin `claude-sonnet-5` rather than use
  `claude-vertex`'s default `claude-opus-4-8`: an Opus arm would have measured
  base-model behavior with the skill never loaded. Not investigated further
  here; it deserves its own scenario.
- **A sandboxed micro-test arm was silently invalid.** The SessionStart hook's
  `mkdir` under `~/.claude/session-env` is denied by the command sandbox, so
  five reps ran with no bootstrap, no skill, and straight-to-implementation
  behavior that read as a catastrophic regression. The extractor now emits
  `bootstrap=ok|FAILED-DO-NOT-SCORE` per rep. Any future micro-test that runs
  agent CLIs needs the sandbox disabled or this check honored.
