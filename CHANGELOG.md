# Hyperpowers Changelog

This file records **this fork's own releases**. The fork's version stream is independent of upstream Superpowers and may collide numerically with upstream tags without sharing content; the current upstream base is recorded in [`.upstream-version.json`](.upstream-version.json). Upstream's release history is preserved unchanged in [RELEASE-NOTES.md](RELEASE-NOTES.md).

## 6.9.2 (2026-08-20)

- **Visual companion is no longer scoped to the architectural path.** The three-path router split (6.9.0) moved the companion's just-in-time step under the `**Architectural:**` checklist header — the line itself was never edited, but the new header landed above it — leaving spike and bounded brainstorms with no mention of the companion at all. Bounded is the modal classification for work in an existing repo, so in practice the companion stopped being offered. It now has a path-independent trigger paragraph (mirroring the Codex approach gate's, added in the same commit that caused the regression), a step on the bounded checklist, and a Red Flags row for "It's bounded, so the visual companion doesn't apply". The `## Visual Companion` section moved above `## After the Design (architectural path)` so it no longer reads as architectural-only. Ceremony still does not escalate: a bounded task that opens the companion stays bounded and still ends in a short in-chat design.
- **New eval scenario** `brainstorming-bounded-fires-visual-companion` guards the bounded path (companion opened just-in-time, no spec file, no plan document).
- **Evidence is inconclusive and recorded as such** (`evals/docs/experiments/2026-08-20-visual-companion-path-scoping.md`). The failure mode reproduced once pre-fix — an agent classified BOUNDED and then stated it would "stay in the terminal rather than opening the visual companion" — but post-fix 3/3 vs pre-fix 2/3 is not statistically distinguishable at that sample size. The change is kept on structural grounds, with no observed cost: across all six runs the bounded classification held, no spec file appeared, and writing-plans never fired.

## 6.9.1 (2026-08-20)

Post-release fixes from the upstream-sync final review train (fable whole-branch review plus the final Codex gate, which surfaced four confirmed findings the earlier per-task reviews missed).

- **SDD workspace identity hardened.** `sdd-dir` resolves the physical plan path (`pwd -P`), so symlinked checkouts map to one workspace (regression test added), and the resume rule now treats the workspace as the plan's identity — controllers resolve the ledger's plan line and compare the file it points to, not the raw string. A ledger line resolving to a genuinely different plan means a corrupt workspace: stop and surface, never silently start fresh.
- **Brainstorming process-flow digraph carries the bounded-path approach gate**, matching the any-path prose contract (the graph previously let bounded requests bypass the conditional Codex approach gate).
- **Upstream base metadata recorded**: `.upstream-version.json` and the README now state the synced base v6.3.0 (`b36e082`) and document the port-based, three-release sync.
- **Final-wave review slots**: `re-review-prompt.md` gains a Final-wave usage note (plan file in the brief slot, final-review findings list), and the shared-cap round accounting parenthetical now states that all fix/re-review rounds count whatever the finding's origin.
- **Doc corrections**: restored the tuned SDD "plan example code is a starting point" red-flag clause; the Windows polyglot-hooks doc names `hooks-codex.json` with its shipped matcher (`startup|clear|compact`); the porting guide's Codex matcher string corrected to the same.

## 6.9.0 (2026-08-19) — upstream sync batch 3

- **Brainstorming rebuilt as a three-path router.** Every request is classified out loud — spike, bounded, or architectural — and the ceremony scales with the class while the approval gate never does: feasibility spikes get a 2-3 sentence probe plan, bounded changes get a short in-chat design (no spec file), and architectural work runs the full questions → approaches → sectioned design → written spec pipeline. The ratchet is one-way: hidden complexity upgrades the path mid-task; nothing downgrades.
- **Classification keys on outcome shape.** A request naming structure the repo does not have — a new module or layer, a new subsystem, reuse across components that do not exist yet — is architectural even when the first edit looks small; algorithm choices inside an existing function stay bounded. (Eval-driven fix: the initial router text let agents classify by whether the entry-point code exists.)
- **Any-path Codex approach gate.** Real architectural/algorithmic/data-model alternatives — or an explicit request for Codex input — fire the approach gate on any path; on the bounded path its approaches fold into the in-chat design without escalating ceremony.
- **Visual companion**: corrected Copilot CLI backgrounding guidance.
- Release-gated by live evals: adversarial-brief escalation 5/5 (threshold ≥4/5), no-downgrade 5/5, and a bounded-path guard proving the approach gate fires without a spec file being created.

## 6.8.0 (2026-08-19) — upstream sync batch 2

- **Plan-scoped SDD workspaces.** Each plan's scratch (ledger, briefs, reports, review packages) lives in its own cache directory (`~/.cache/hyperpowers/sdd/<repo-key>/plans/<plan-slug>-<hash8>/`), so concurrent plans cannot read or corrupt each other's state; idle sibling workspaces are garbage-collected after 14 days; finish deletes the plan's workspace with real verification (`test ! -d`).
- **SDD lifecycle restructure** (Setup → Task Loop → Final Review → Finish) with a **unified fix loop**: Codex-gate findings and Claude-reviewer findings share one five-round cap per task, one gate directory per task lifecycle (persisted in the ledger across compaction), gate ceilings computed in the shared-cap coordinate system, and a breaker that surfaces BLOCKED to the human rather than parking findings.
- **File-based handoffs threaded through**: `task-brief` and `review-package` carry the plan identity; the review package signature is `PLAN_FILE BASE HEAD [OUTFILE]`.
- **writing-plans** carries a Spec header linking each plan to its source spec.
- Release-gated by live evals: fix-loop convergence and plan-scoped workspace isolation (the latter caught and drove the delete-at-finish hardening).

## 6.7.0 (2026-08-18) — upstream sync batch 1

Clean ports from upstream Superpowers v6.0.2..v6.3.0 (pinned at `b36e082`), PORT-NORMALIZED to this fork's namespace:

- **finishing-a-development-branch** wholesale port: environment detection, provenance-based worktree cleanup, detached-HEAD menu.
- **test-driven-development**: writing-good-tests rewrite.
- **Bootstrap compression**: the session-start `using-hyperpowers` text is markedly smaller, and stale reference content was pruned.
- **requesting-code-review**: reviewers get an explicit no-subagents contract (no spawned sub-reviewers or second opinions).
- **Fixes**: render-graphs.js, find-polluter.sh, harness test repairs, portability nits, and brainstorm-server branding tests (root cause: telemetry env leakage into test sessions).

## 6.6.2 (2026-08-17)

- **writing-plans** defaults the execution handoff to subagent-driven development instead of prompting for an execution method.

Earlier fork history (Codex review gates, risk tiering, review sweep, claude.ai packaging, and the original rebrand) is recorded in the git log.
