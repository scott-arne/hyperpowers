# Gate Resilience & Telemetry (6.4.0) — Eval Evidence

Date: 2026-07-23
Branch: `feat/gate-resilience-telemetry` (23 commits; merged to `main` at `853f84a`, branch deleted)
Spec: `docs/hyperpowers/specs/2026-07-23-gate-resilience-telemetry-design.md`
Plan: `docs/hyperpowers/plans/2026-07-23-gate-resilience-telemetry.md`
Predecessor: 6.3.0 (`2026-07-23-gate-reliability-hardening-eval-evidence.md`)

## Release-gate state

- **Final Claude whole-branch review (fable): READY TO MERGE**, reconfirmed
  twice after post-verdict fixes. All seven spec §8 acceptance criteria
  met (criteria 1/4/5 with recorded caveats: event uniqueness rests on
  prose + the reserved live eval; the sweep's GATE_DIR-from-source is
  doc-prescribed, worktree-key absence proven only for the ungated root;
  the fleet aggregate omits one doc-recorded sum — Minor-ledgered).
- **Final Codex whole-branch gate: normalized `approve` on round 2**
  (via `verdict-normalize`, the release's own authority — dogfooded for
  every gate in this cycle). Round 1's two highs were real and fixed in
  `853f84a`: pre-write lock ownership revalidation (`still_owner()`
  before both ledger writes) and the sweep's lost-inputs fallback
  (GC'd-context events route through the code-review-requests recipe;
  the recorded `base..head` is always reconstructible).
- Suites at hand-off: 29 ledger checks, 22 gate-round checks, 22
  telemetry checks, 6 notice checks, 7 sweep-toolchain checks, 92
  contract needles; full sweep 14 files / 248 assertions green at the
  bump; `bump-version.sh --audit` clean at 6.4.0; evals `quorum check`
  green at 54 scenarios.

## Gate history (all through the 6.3.0 machinery, live)

Every review in this cycle ran through the machinery 6.3.0 shipped:
`codex-preflight` before gates (status `ok` v1.0.6 throughout — zero
degrades this cycle), `base-ref-ok` before every `adversarial-review`,
`verdict-normalize` as the only approval authority. The §4b lost-job-id
recovery path fired once in anger (a status-poll race) and recovered via
the documented `latestFinished` snapshot.

- **Spec gate: approve in 4 rounds** (r1: sweep didn't constrain to the
  recorded head + internal preflight failures lacked a ledger token —
  the `preflight-error` token closed a 6.3.0 carryover; r2: `base-ref-ok`
  validated against the wrong checkout — moved inside the worktree; r3:
  the detached-worktree sweep could close the WRONG repo's ledger
  (linked worktrees have distinct git-dirs) — source-repo anchoring
  added).
- **Plan gate: 4 rounds to the document-gate backstop**, two plan fixes
  shipped post-backstop per the gate's own rule (class-1 templates drop
  `--gate-dir` with the forensic-only rationale; GNU-first numerically
  validated stat probe) — both later validated in the shipped
  implementation under per-task gates. Round 1 also ran the Algorithm
  Assessment: two alternatives suggested (bucketed per-gate telemetry
  aggregate; `mapfile` de-dup) — both adopted.
- **Per-task gates:** T3 and the eval/bump tasks approved round 1; T4
  converged round 3; T6 exhibited the spec's predicted calibration flow
  exactly (medium-only `needs-attention` → minor noted → one confirming
  round → approve). **T1, T2, T5 each ran to the 3-round code-gate
  backstop** with the final fix shipping under the §5 backstop rule and
  re-examined by the final gates:
  - T1 (`ungated-ledger`): five real lock defects across the review
    chain — trap-order leak, foreign-lock rmdir on timeout, paused-owner
    release race (ownership tokens + atomic mv-reap), tokenless
    loop-exit acquisition, unchecked owner write (`own_lock` verify).
    The final Claude reviewer later judged the complete protocol sound
    end-to-end; the final Codex gate added the pre-write revalidation.
  - T2 (`gate-round`): three fail-open state defects — silent reset on
    damaged state, non-numeric ceiling passing peek, `||0` defaults
    defeating the raw-field sentinel.
  - T5 (§7 sweep): shared sweep-wide GATE_DIR let the first event spend
    every later event's ceiling (per-event fresh dirs now), then recipe
    fidelity twice (final events → whole-branch recipe; adhoc events →
    code-review-requests recipe).
- **Wording micro-tests** (writing-skills discipline, controller-run,
  all PASS): §5 backstop stimulus (refused re-invocation, full
  hand-back, exact class-2 append with event id) and §7 consent stimulus
  (surfaced nothing, launched nothing without consent).

## Controller-visible process notes

- One fixer subagent committed the six `docs/hyperpowers/` working files
  mid-task (same failure mode as a 6.3.0 fixer); the controller rebuilt
  the commit without them (`7f9765f` → `223f136`). Fixer dispatch
  prompts now carry explicit stage-only-your-files instructions.
- The accepted residuals are recorded in spec §6/§9, including the one
  the final review added: gates degraded inside a linked development
  worktree append under the worktree's key and orphan silently when it
  is removed (mitigation candidates named for a follow-up:
  finishing-a-development-branch pending-check, or keying off
  `--git-common-dir`).

## Live-run evidence hooks (reserved for the human partner)

- `codex-gate-stale-broker-attributed` now additionally asserts the
  durable class-1 append (`"class":"degraded-gate"` +
  `"status":"stale-broker"` on one event line) and therefore **requires
  hyperpowers ≥ 6.4.0 as the plugin under test** (evals commits
  `4604b06`; the `min_version` frontmatter key is doc-only — the harness
  ignores unknown keys; the prose carries the constraint). Run after
  6.4.0 ships:
  `cd evals && bun run quorum run scenarios/codex-gate-stale-broker-attributed --coding-agent claude-vertex && bun run quorum show`
- First real telemetry snapshot: `bash skills/requesting-code-review/scripts/gate-telemetry`
  on this repo after merge — this cycle's scratch dirs (three backstops,
  one calibration flow, zero degrades) are themselves a fixture-grade
  dataset, and a `--json` snapshot here is the before-baseline for
  sub-project 3's efficiency claims.
