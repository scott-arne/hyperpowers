# Skeleton plus delta

- Status: accepted
- Spec: docs/hyperpowers/specs/2026-10-21-decision-records-design.md (decision 6)
- Recorded: 2026-10-22; notes from the branch diff by a subagent at finish; plan docs/hyperpowers/plans/2026-10-21-decision-records.md removed at finish

## Decision

**Skeleton plus delta.** A dependency-free script lifts the spec's
decision items verbatim into records; a background subagent adds only one
section per record, what implementation changed, plus proposals the
human partner rules on. The approved spec is the sole source of the why
and the sole authority for supersession; the model writes only what the
spec could not know. Independent approach proposals from Codex converged
on two alternatives and offered a third: a deterministic compiler alone
(loses implementation-time discoveries unless a correction carries them),
a model-only extractor (every rationale probabilistic), and a dossier
event log with a finish-time reducer (the per-task capture rejected in
decision 2, and dependent on the unfinished dossier work). The skeleton
ships even when the delta cannot run.

## What implementation changed

The script is bash using only git, awk, sed and date, and its suite is `test-decisions-compile.sh` (303 checks at the last run). The delta is `decision-notes-prompt.md`, and `load_notes` parses its output into one section per record plus proposals. The notes grammar is enforced strictly (first line, ATX and setext headings, range, duplicates, list-only optional sections) and a bad file is ignored whole with a stderr line, so the skeleton always compiles. Proposals and supersession lines are counted and never applied by the compiler.
