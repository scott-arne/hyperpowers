# The evidence bar is tests, a field replay, a treatment-only scenario and one Zed run, recorded in a preregistered evidence note

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-11-10-sdd-dispatch-guard-design.md (decision 9)
- Recorded: 2026-11-11; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-11-10-sdd-dispatch-guard.md removed at finish

## Decision

**The evidence bar is tests, a field replay, a treatment-only scenario and
one Zed run, recorded in a preregistered evidence note.** Unit and wrapper
tests cover every decision; an offline replay over a frozen corpus (every
`Agent` and `SendMessage` call the 10 field sessions made under v6.17.0,
counted and hashed in the Testing section), with the plan check forced
on, lists every call the hook would refuse and must show no refusal of a
dispatch the skill allows during a plan; a five-run scenario in which
every counted run contains a `SendMessage` refusal, and at least one run
a background-`Agent` refusal, must show each refusal followed by a
foreground dispatch and no turn end with a live agent, 5 of 5; one
uncounted fork-mode run must refuse nothing; one manual Zed run must show
the thread working through a `SendMessage` refusal and its re-dispatch. The
criteria are written into
`docs/hyperpowers/2026-11-10-sdd-dispatch-guard-eval-evidence.md` before
the first run, and the note cites the committed artifacts in
hyperpowers-evals. Rejected: a control arm, following the stop guard's
"one treatment arm, unit tests, and the field": the hook is deterministic
and the control's behaviour is the field data above. Rejected: replay
plan windows from the stop-guard logs, because a Stop line marks a point
inside a plan rather than its bounds and three of the ten sessions have
no stop-guard log.

## What implementation changed

Carried out with these results. The replay ran on a frozen copy of the corpus, because ae183251's transcript gained a timestamp-less `tools-used` line after the manifest was written (plan Correction of 2026-11-10; `freeze.mjs` added in Task 5 fix round 1). It covered 329 calls, 59 refusals (48 expected, 11 outside a plan, 0 false). The scenario passed 5 of 5 counted runs with 0 void, every one holding a paired `background-agent` refusal, and the fork-mode run refused nothing. The one Zed run passed with 2 of 2 refusals paired. No run observed a fix round re-dispatched with findings. Every `SendMessage` refusal answered the scenario's scripted Task 1 docstring follow-up, and the Zed one was the same follow-up. Quorum's own grade failed 4 of 5 scenario runs on the fixture's end state, which the pairing rule does not read. Evidence is in the evidence note and in hyperpowers-evals.
