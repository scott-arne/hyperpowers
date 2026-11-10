---
sources: skills/requesting-code-review skills/brainstorming/codex-approach-gate.md skills/brainstorming/SKILL.md skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md skills/subagent-driven-development/risk-tiers.md hooks/session-start scripts/claude-skill-root.md
source-digest: a1b1df3adc90
---
# Codex reviews

Hyperpowers can ask Codex for an independent review at five points: when brainstorming weighs approaches, over the written spec, over the written plan, after each task during subagent-driven development, and over the whole branch at the end. This page covers how those reviews run, how a result counts as an approval, and what happens when Codex is not available. The skill-level summary is in {doc}`../skills/requesting-code-review`.

The reviews use the `codex-plugin-cc` plugin. They run under Claude Code only. The gate document says to skip the gate silently in any other harness, with no preflight and no notice. The Claude Desktop and claude.ai bundle is the exception: its router document, {source}`scripts/claude-skill-root.md`, tells the agent to print one notice ("Codex review gate unavailable in this environment; proceeding per skill's no-Codex path") the first time it reaches a gate, and then to follow the skill's fallback. Every skill that uses a gate keeps working without Codex, so the gate is optional everywhere.

The shared gate text is {source}`skills/requesting-code-review/codex-review-gate.md`. It lists the section files and a route for each caller: the approach gate reads one file, and each spec, plan, task, final, and ad-hoc review reads the preflight, setup, output schema, lens, recipe, findings, and fix-loop files.

## The five gates

**Approach gate.** {source}`skills/brainstorming/codex-approach-gate.md` runs inside brainstorming's approach step. It fires when there are at least two genuinely different viable architectures, algorithms, or data models with materially different tradeoffs, or when you ask for Codex input in any phrasing. It stays silent for a trivial or mechanical task. It is one shot: no fix loop, no round ledger, and no re-review. The agent writes a handoff file with your original idea verbatim, each clarifying question with your answer, and codebase facts. The file excludes the agent's own candidate approaches so Codex's ideas stay independent. Codex returns two or three approaches in a fixed shape. The agent merges approaches that converged, drops inapplicable ones with a visible one-line reason, and presents the shortlist with `(Codex)` or `(both converged)` tags and a single recommendation. The skill says to judge approaches on merit, with no preference for the agent's own.

**Spec gate.** After the spec self-review passes and before you are asked to review the spec, {doc}`../skills/brainstorming` runs a document review over the spec file. The gate never blocks your review of the spec. At worst it is skipped.

**Plan gate.** {doc}`../skills/writing-plans` runs a document review over the plan, with the source spec, before the execution handoff. It checks feasibility, task sizing, missing steps, ordering, type and signature consistency, and spec coverage. The review also checks each task's declared risk tier against the rubric, and the rubric's three tier definitions go into the review context, because the reviewer is stateless and cannot load the skill. On round one, when the plan has material algorithm or data-structure choices, the review also assesses them. The agent adjudicates each assessed choice and records it in the round ledger as a lock that later rounds do not reopen without a new blocking defect in that choice.

**Per-task gate.** In {doc}`../skills/subagent-driven-development`, after the task reviewer approves and before the completion line is written, a code review runs over the task's range from the base commit recorded before the implementer was dispatched. Codex receives the task brief, the implementer report, the review package, and the global constraints as file paths.

**Final gate.** After the whole-branch reviewer and its fix wave, and before finishing, a code review runs over the branch from its merge base. It receives the branch review package, the plan or requirements, the minor-findings ledger when one exists, and the tier-skip summary when any task skipped its gate. An ad-hoc code review through {doc}`../skills/requesting-code-review` uses the same machinery over the range the Claude reviewer used.

## Round one: lenses

Round one of every review except the approach gate fans out into lenses: narrower reviews over one shared dossier of the change. A dossier is a file that {source}`skills/requesting-code-review/scripts/review-dossier` assembles from the spec, plan, ledgers, test evidence, and diff. An input the dossier lacks is rendered as `NOT PROVIDED`, and the reviewer marks that coverage axis as cannot-verify. The whole lens batch counts as one round.

| Gate | Lenses |
|---|---|
| Spec | completeness-and-consistency; feasibility-and-scope |
| Plan | coverage-and-ordering; feasibility-and-contracts |
| Per-task and ad-hoc code | correctness; contracts-and-integration; tests-and-evidence |
| Final | correctness; integration-and-requirements-coverage; tests-and-evidence |

Each lens reviewer is told to report every blocking finding it can identify that round, to label findings outside its lens `[out-of-lane]`, and to add a `Coverage:` section. Document gates run their lenses one after another in the foreground, each call with an explicit 600000 ms (10 minute) timeout. Code gates launch each lens detached, record its job id straight after the launch, and then watch all ids with one `gate-wait` call. The agent keeps a blocking watch open for the whole review and caps it at two consecutive `gate-wait` calls (about 16 minutes), after which the result counts as incomplete.

## Approval: `verdict-normalize` is the only authority

Every capture goes through {source}`skills/requesting-code-review/scripts/verdict-normalize`, which returns `approved`, `blocking`, or `incomplete`. Only `approved` counts. The skill's rule is that the agent never derives approval from its own reading of raw output, and never from the absence of output. Round-one captures run with `--require-coverage`, so the coverage section is part of what approval requires.

The round's result merges across lenses so that a failure cannot hide:

- All lenses `approved`: the round is approved.
- Any lens `incomplete`, after its recovery: the round is incomplete. Blocking findings from the other lenses still enter the ledger as work, and nothing approves.
- Otherwise the round is blocking.

Findings that cite the same file and offending code and describe the same failure merge into one ledger entry with every reporting lens's tag, and the strictest severity survives.

**Severity mapping.** Codex `critical` maps to Critical and `high` to Important, and both block. `medium` and `low` map to Minor, which is noted and not fixed in the loop.

**Incomplete is not approval.** A result is incomplete when, for example, a launch exits non-zero or its job never appears, the watch cap is reached with the job still running, a foreground call is aborted by its timeout, the payload has no terminal verdict, or the text reads as in progress. The agent recovers within a bound (a final `status`, at most one relaunch if the failure looked transient, and, optionally, `cancel` for a stalled worker). If it is still incomplete, the agent reports "Codex review did not complete" and does not pass it. The unrecovered event is recorded in the ledger of ungated work.

## The fix loop and its ceilings

Rounds after the first use a single reviewer and no lenses. Before each one the agent writes a round ledger into the gate's scratch directory and hands Codex its path. The ledger records, per round, what was resolved and how, what was declined with file and line evidence, and what is still open. The round-two preamble tells Codex to confirm that the resolved findings are fixed, to leave declined ones alone unless it can show the stated reasoning is wrong, and to raise only new blocking findings, with no new Minor ones. Minor findings that arrive anyway are recorded and left alone.

Each blocking finding is treated as a claim to check before fixing. The agent lands it in one of three states:

- Confirmed: fixed, or accepted as a risk only by you, recorded in your words.
- Declined: allowed only as refuted (the cited code does not do what the finding says) or corrected (the defect exists but not at blocking severity or not in this change's scope), with evidence in the ledger.
- Unsettled: stays blocking.

After any code fix, the Claude reviewer runs again before Codex does.

A script, {source}`skills/requesting-code-review/scripts/gate-round`, counts the rounds, and its count is the authority over the agent's recollection. A round converges only when every capture in its set normalized to `approved`, the round raised no blocking findings, and the ledger has no open blocking finding. The ceilings come from the gate-fix-loop file:

| Gate | Ceiling |
|---|---|
| Spec and plan | 4 rounds |
| Final, and ad-hoc code-review requests | 3 rounds |
| Per-task | no ceiling of its own: its rounds share the task's five-round fix cap with the Claude reviewer's rounds |

For the per-task gate, the SDD skill passes the script the count of the task's non-gate fix rounds, and the script derives the ceiling from the five-round cap, so that gate rounds plus other fix rounds never exceed five. When the cap is already spent, the task is reported BLOCKED to you.

When a ceiling is hit, the agent hands the unresolved blocking findings back to you. A blocking finding first raised in the ceiling round has no round left to confirm its fix, so the skill gives three dispositions: carry it to you as unresolved, fix it and open a follow-on review now, or fix it and defer, after telling you plainly that the fix is unreviewed. Fixes applied in that round ship without a Codex confirmation, and the hand-back says so. For code gates the agent also records them in the ledger of ungated work, which schedules a follow-on review of the range.

The hand-back for any gate lists the Codex verdict, the round count and whether the loop converged or hit the ceiling, what was flagged, fixed, and declined, unresolved findings, unreviewed fixes, Minor findings left alone, any incomplete result and how it ended, and the review runtime.

## Risk tiers and the per-task gate

Each plan task declares a tier of low, standard, or high. The tier changes one thing: a task skips the per-task Codex review only when all three hold. The task is declared low, the plan gate actually reviewed the plan, and no escalation trigger fired during execution. The triggers in {source}`skills/subagent-driven-development/risk-tiers.md` include a fix cycle, a file touched outside the plan's list, a done-with-concerns report with correctness doubts, and anything on the high list surfacing mid-task. A tier is raised and never lowered. The skip is recorded in the ledger of ungated work. If the plan gate was skipped or degraded, or its outcome is unknown, the low tier executes as standard. The Claude task reviewer and the final gate never tier off.

## Without Codex

The preflight, {source}`skills/requesting-code-review/scripts/codex-preflight`, prints one JSON status, and the agent runs it at most once per skill run and reuses the result. Each status below other than `ok` produces one notice that names the status, and the review then continues without Codex.

| Status | Meaning in the gate text | Notice |
|---|---|---|
| `ok` | A Codex review can run | none, except a one-time line per skill run when ungated items are pending ("N ungated review item(s) pending sweep in this repo") |
| `not-installed` | The plugin is absent | A note with the four install commands |
| `not-ready` | The plugin is installed but Codex is not ready, with a reason | A note naming the reason |
| `stale-broker` | The companion broker for the repository is dead | A note quoting a recovery command to run in a terminal |
| `preflight-error` | The preflight itself failed | A note with the error summary |

The `hooks/session-start` script moves dead broker records aside each time it runs, so the gate text reads a `stale-broker` status as a broker that died after that. Every degraded gate except the approach gate appends an event to a ledger of ungated work, with the gate type, status, and for code gates the range that shipped unreviewed. That ledger feeds the session-start notice that counts pending items, and a review sweep clears the items, but only when you ask for it. The sweep runs a code review over each pending event's exact recorded range. Events from the spec and plan gates are recorded as not sweepable and never appear as pending.

## Why companion commands run outside the Bash sandbox

The gate text says to run the preflight and every companion command in a shell without the sandbox. Its reason is the behavior of version 1.0.6 of the companion: a sandboxed shell may be unable to connect to the broker socket, and the companion reads a connection it cannot make as a broker that is not ready. It then removes the live broker's socket, pid file, and record and starts a replacement it cannot reach either. The original broker keeps running with its jobs, unreachable, and other sessions on the host find a stale record. From a sandboxed shell the preflight itself reports `not-ready` with a `connect EPERM` reason, which says nothing about the broker. The gate text says to repeat the preflight unsandboxed before degrading a gate or quoting a recovery to you.
