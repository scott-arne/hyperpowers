# Gate Resilience & Telemetry — Design

Date: 2026-07-23
Status: draft (spec gate pending)
Target release: 6.4.0
Predecessor: `2026-07-22-gate-reliability-hardening-design.md` (6.3.0, merged)

## 1. Problem

6.3.0 made gate degradation attributed and fail-closed at the moment it
happens. But the moment passes: the attribution lives in conversation prose
(§6 hand-backs, degrade notices) and in scratch dirs that a 14-day idle GC
reclaims. Three durable gaps remain, all measured in the July 2026 mining
pass and re-confirmed during 6.3.0's own development:

- **Ungated work leaves no durable trail.** 174 "gate unavailable" proceeds
  had no consolidated record of which commits shipped without a Codex
  review; finding them required transcript mining. 6.3.0's own release
  produced two backstop-shipped fixes flagged only in conversation.
- **Round ceilings are prose.** The §5 backstops (document gates 4, code
  gates 3) were violated in the wild (a 7-round code gate), and 6.3.0's
  execution hit its backstops twice — the count is kept by the agent, and
  agents lose count.
- **Regressions are invisible until someone mines.** The June→July broker
  failure curve (9 → ~240 monthly transcript hits) was only found by a
  manual fleet-wide analysis. The scratch dirs now carry attributed,
  machine-readable outcomes; nothing aggregates them.

## 2. Approach (decided via Codex approach gate)

Selected architecture: **cache-native repo ledger** (independently proposed
by both Claude and Codex in the one-shot approach gate; chosen over a
git-dir ledger with cache mirror, and over run-local records with a
generated index). Same philosophy as 6.3.0's narrow checkers: prose
orchestrates, small contract-tested scripts own every fact that must be
mechanical — here, the durable ungated record, the round count, and the
aggregated metrics.

Human-partner decisions binding this design:

- Ledger scope: all three ungated classes (degraded gates, backstop-shipped
  fixes, incomplete-review proceeds).
- Sweep consent: surface + ask. Detection automatic (session-start notice,
  healthy-preflight re-surface); execution only on explicit consent.
- Ceiling mechanism: `gate-round` counter checker in `GATE_DIR`; wrapper and
  hook designs recorded as escalation paths, not built.
- Telemetry: one read-only script, markdown to stdout + `--json`, current
  repo default + `--all`; scratch dirs only, no transcript mining; no
  automatic history file (snapshots are files the user saves).

## 3. Goals / non-goals

Goals:

1. Every gate outcome that ships work without a Codex confirmation appends
   a durable, machine-readable event that survives normal repo and scratch
   lifecycle until swept.
2. The human partner cannot un-knowingly ignore the backlog: a one-line
   notice at session start and at any healthy preflight while entries are
   pending.
3. A consented sweep re-reviews pending code ranges with the ordinary gate
   machinery and closes the loop with appended `swept` events.
4. Round ceilings are mechanically counted; exceeding one without the
   documented backstop procedure becomes impossible to do silently.
5. One command turns the scratch dirs into the release-health numbers the
   July mining produced by hand.

Non-goals:

- No automatic sweep execution, no cron, no dashboards, no history file.
- No transcript mining in telemetry.
- No changes to review-package content or prompt efficiency (sub-project 3).
- No invocation wrapper or PreToolUse enforcement (recorded escalation
  paths if evals show `gate-round` being skipped).
- No migration of 6.3.0-era or older scratch data; telemetry tolerates old
  formats but does not backfill events for pre-ledger degrades.

## 4. Components

All new scripts live in `skills/requesting-code-review/scripts/`, bash +
node built-ins only (no jq). Shared error discipline (6.3.0 contract): exit
0 for every determinate answer with single-line JSON on stdout; non-zero
exit means the tool itself failed, and callers map that to the conservative
outcome.

### 4.1 `ungated-ledger` — durable ungated-work record

Storage: `${XDG_CACHE_HOME:-~/.cache}/hyperpowers/ungated/<repo-key>/ledger.jsonl`,
where `<repo-key>` is derived exactly as `sdd-dir` derives it (SHA1 of the
repo's absolute git-dir path) so one repo has one key across all three
scratch roots. The `ungated/` root is a NEW tree, deliberately outside
`sdd/` — no GC touches it. Append-only JSONL; `swept` events append rather
than mutate.

Event shapes (`v:1`):

```json
{"v":1,"id":"<ts>-<rand>","event":"ungated",
 "class":"degraded-gate|backstop-fix|incomplete-review",
 "gate":"spec|plan|task|final|adhoc","ts":"<ISO8601>",
 "repo":"<git-root realpath>","base":"<sha|null>","head":"<sha|null>",
 "status":"<preflight token|null>","sweepable":true,
 "gateDir":"<GATE_DIR path>","note":"<one line>"}
```

```json
{"v":1,"event":"swept","ref":"<id>","ts":"<ISO8601>",
 "verdict":"approved|blocking|incomplete|unsweepable","note":"<one line>"}
```

Pending = `ungated` events with `sweepable:true` and no `swept` event
referencing their `id`. `sweepable` is derived from `--gate` at append
time: `spec|plan` → `false` (base/head null, not required); `task|final|
adhoc` → `true`, and `append` fails (exit 2, usage) if `--base`/`--head`
are missing for a sweepable gate. `gateDir` is a forensic breadcrumb only —
nothing may depend on the run dir surviving. Unsweepable events never
count toward the §4.3/§1 pending notice; they exist for telemetry.

Subcommands:

- `append --class C --gate G [--base SHA --head SHA] [--status TOKEN]
  [--gate-dir P] [--note S] [repo-dir]` → `{"ok":true,"id":"..."}`.
  Writes under a portable lockdir (`ledger.lock/`, mkdir-based) with
  stale-lock takeover after 30 seconds; a takeover is recorded in the
  event's `note`.
- `pending [--count] [repo-dir]` → JSON array of pending events, or with
  `--count` exactly `{"count":N,"skipped":M}` where `skipped` counts
  corrupt/torn lines ignored while reading. Hook and gate callers read
  `.count` only; telemetry surfaces `.skipped`. Read-only, lock-free: the
  file is append-only and readers skip a torn final line.
- `mark-swept --ref ID --verdict V [--note S] [repo-dir]` → appends the
  `swept` event (same lock).

### 4.2 `gate-round` — mechanical round counting

`gate-round GATE_DIR --ceiling N` increments a counter file in the per-gate
scratch dir (beside the round ledger) and prints
`{"round":K,"ceiling":N,"verdict":"proceed|backstop", ...}`. `--peek` reads
without incrementing. When `verdict` is `backstop`, the JSON carries a
`reminder` field holding the exact `ungated-ledger append --class
backstop-fix ...` command template for the gate's hand-back step.

Single responsibility: `gate-round` counts; it never writes the ledger (it
does not know base/head). The gate doc makes the class-2 append a required
step of the backstop procedure, and the reminder makes it hard to forget.

Gate-doc wiring (`codex-review-gate.md` §5): composing ANY round's Codex
prompt requires a preceding `gate-round` call for that `GATE_DIR` with the
gate's ceiling from the backstop table; a `backstop` verdict forbids
invoking Codex again for that gate. A Red Flag pins it: never invoke the
companion for a review round without a `proceed` from `gate-round`.

### 4.3 Session-start notice (in `hooks/session-start`)

Janitor pattern, second guarded block: if the `ungated/` root exists for
the current repo key and `ungated-ledger pending --count` reports N > 0,
append one line to the injected session context:

> N ungated review item(s) pending sweep in this repo — say "run the
> review sweep" to clear them.

Guarantees (same bar as the janitor): guarded subshell, all failures
swallowed, stdout JSON purity, instant no-op when the root is absent
(cross-harness safe), one cheap file read — no measurable startup cost.

### 4.4 The review sweep (`codex-review-gate.md`, new §7)

Runs only on explicit human consent, surfaced by §4.3's notice or by a
healthy §1 preflight re-surface (below). For each pending event:

1. Resolve the recorded `head` first:
   `git rev-parse --verify <head>^{commit}`. Unresolvable (repo rebased,
   commits gone) → close the event as `swept` with verdict `unsweepable`
   and an attributed note — never left pending forever, never launched.
2. Establish the review checkout, THEN validate the base against it —
   `base-ref-ok` judges merge-base and empty-range against the checkout's
   own `HEAD` by contract, so validation must run where `HEAD` is the
   recorded head, never against the ambient checkout:
   - Fast path — current `HEAD` equals the recorded `head`: run
     `base-ref-ok <base>` in place; on ok, run the ordinary code recipe
     in place (`adversarial-review --base <base>`).
   - Else: create a throwaway detached worktree at the recorded `head`
     (`git worktree add --detach <tmpdir> <head>`), run
     `base-ref-ok <base> <tmpdir>` there, and on ok run the recipe from
     that worktree with the same `--base`. Remove the worktree afterwards
     (`git worktree remove`, `git worktree prune`) — cleanup happens even
     on a failed validation or review (the worktree is disposable by
     construction).
   A failed `base-ref-ok` against the recorded head closes the event as
   `swept`/`unsweepable` with the checker's reason. The review is always
   of exactly the recorded `base..head`, never `base..current-HEAD`.
   Captured output goes through `verdict-normalize`, inside the §5 loop
   with a FRESH per-event `GATE_DIR` (created from the source repo for
   each pending event) and `gate-round` at the code-gate ceiling — a
   shared sweep-wide dir would let the first event's rounds spend the
   ceiling for every later event.

   **Source-repo anchoring (worktree path).** Repo keys derive from the
   absolute git-dir path, and a linked worktree has a DIFFERENT git-dir —
   so nothing key-derived may run cwd-based from inside the throwaway
   worktree. Before creating any worktree, the sweep captures the source
   repo root (`SWEEP_REPO`), creates its `GATE_DIR` from the source repo
   (`codex-review-dir` run there), and passes `"$SWEEP_REPO"` explicitly
   as the `[repo-dir]` argument to EVERY `ungated-ledger` call — `pending`,
   every `mark-swept`, including `unsweepable` closures. Only the git
   commands of the review itself run in the worktree.
3. `mark-swept --ref <id> --verdict <tri-state>`; blocking findings route
   into the session's normal fix machinery (the sweep surfaces them; fixing
   them is ordinary work the human directs).

Sweep scoping: only code-range events are sweepable. Document-gate
class-1 events are recorded `sweepable:false` — by sweep time the artifact
has usually evolved or shipped, and its content is covered by the code
gates that followed; they still count in telemetry.

§1 re-surface: when preflight returns `ok` and `pending --count` > 0, the
gate emits the same one-line notice once before proceeding with its own
review. It never blocks or delays the gate itself.

### 4.5 `gate-telemetry` — scratch-dir aggregation

`gate-telemetry [--json] [--all] [repo-dir]` reads, read-only:

- `sdd/<key>/` — progress ledgers, task/fix briefs and reports;
- `codex-review/<key>/run-*/` — round ledgers, gate-round counters,
  captured verdict files;
- `ungated/<key>/ledger.jsonl`.

Metrics (per repo, and aggregated under `--all`): rounds-per-gate
distribution and backstop rate by gate type; degrades by preflight status
token; fix-cycle rate (tasks with fix briefs / tasks); ungated backlog
(pending count, oldest pending age) and sweep outcomes; counts of artifacts
skipped as unparseable or old-format — reported explicitly, never silently
dropped. Default output is a compact markdown report to stdout; `--json`
emits the same numbers machine-readable (for saved snapshots and
sub-project-3 before/after comparison). No state is written anywhere.

### 4.6 Gate-doc amendments summary

- §1: degrade branches (`not-installed`, `not-ready`, `stale-broker`,
  internal failure) append a class-1 event (status token in hand; doc gates
  append `sweepable:false`); healthy preflight with pending entries emits
  the one-line re-surface notice. Internal failure gets its own token:
  the non-zero-exit branch changes from "treat exactly as not-installed"
  to its own notice `Note [status: preflight-error]: ...` (same degrade
  behavior, distinct attribution) and appends `--status preflight-error` —
  this also closes the 6.3.0 carryover finding that checker crashes were
  misattributed as `not-installed` in transcripts.
- §4b: the final "review did not complete — not an approval" path appends a
  class-3 event before proceeding.
- §5: round composition requires `gate-round`; the backstop procedure
  appends the class-2 event (using the reminder template) and the §6
  hand-back names the event id.
- §7 (new): the review sweep procedure (§4.4).
- Red Flags: no companion round-invocation without a `gate-round`
  `proceed`; no backstop exit without its class-2 append.

## 5. Lifecycle

1. Session start → janitor sweeps brokers (6.3.0) → ungated notice if
   pending > 0.
2. Gate start → preflight → `ok` + pending > 0 → one-line re-surface;
   degrade → class-1 append + attributed notice (6.3.0) and the gate
   proceeds as today.
3. Each review round → `gate-round` → `proceed` composes the round;
   `backstop` → documented backstop procedure + class-2 append when fixes
   ship post-backstop.
4. Incomplete after bounded recovery → class-3 append + existing surfacing.
5. Human consents to a sweep → §4.4 → `swept` events close entries.
6. Any time: `gate-telemetry` renders the current picture from scratch.

## 6. Error handling and safety

- The notice block can never break, slow, or pollute `hooks/session-start`
  (guarded subshell, swallowed failures, stdout purity — janitor bar).
- A failed ledger append never blocks a gate: the gate warns loudly in its
  hand-back ("ungated event could NOT be recorded — note this manually")
  and continues; the cure stays cheaper than the disease.
- Lock discipline: mkdir lockdir, 30s stale takeover, takeover noted in the
  event. Readers never lock.
- Corrupt/torn ledger lines are skipped and counted; `pending` and
  telemetry report the skip count.
- The sweep never launches a review for an invalid base (`base-ref-ok`
  first) and closes unresolvable entries as `unsweepable` with attribution.
- Residual risk, accepted and documented: a user-initiated cache wipe loses
  pending records. Blast radius equals the pre-ledger status quo, and any
  surviving entries re-surface at the next session start in that repo.

## 7. Testing

- **Script tests** (bash, `tests/codex-review-gate/`): ledger round-trip
  (append → pending → mark-swept → pending empty), doc-event
  `sweepable:false` handling, concurrent appends (two backgrounded
  writers, both events present, valid JSONL), stale-lock takeover,
  corrupt-line tolerance with reported skip count; `gate-round`
  increment/peek/ceiling/backstop matrix incl. the reminder field;
  `gate-telemetry` against a synthetic scratch tree containing current
  format, pre-6.4.0 format, and unparseable files — numbers match fixture
  truth, skips reported, `--json` parses.
- **Hook test** (`tests/hooks/`): notice present when pending > 0, absent
  at zero, absent when root missing, hook stdout still valid JSON.
- **Contract needles** (`test-gate-contract.sh`): the three append moments,
  the `gate-round` requirement + Red Flags, the §7 sweep section, the
  re-surface line.
- **Micro-tests** (writing-skills discipline) for the reworded §5
  round-composition step and the §7 consent gate (a rep must not launch
  the sweep unasked).
- **Eval anchor**: extend `codex-gate-stale-broker-attributed` (evals repo)
  with deterministic post-checks that the class-1 event was appended
  (`command-succeeds` on the ledger path + grep for
  `"class":"degraded-gate"`), keeping its existing AC prose.

## 8. Acceptance criteria

1. A degraded gate (stub fixture) leaves exactly one class-1 event with the
   correct status token; a doc-gate degrade records `sweepable:false`.
2. `gate-round` makes a 5th document round / 4th code round impossible
   without a `backstop` verdict in hand, and its backstop JSON carries the
   class-2 append reminder; the gate doc forbids companion round calls
   without a `proceed`.
3. With pending entries, session start and a healthy preflight each surface
   the one-line notice; with zero pending, neither says anything; the hook's
   stdout contract is untouched (existing hook tests still pass).
4. The sweep procedure closes a valid pending entry via a real code-recipe
   review path (stub-tested) and closes an invalid-base entry as
   `unsweepable`; nothing is launched without consent (micro-test). The
   detached-worktree path is test-proven to close the SOURCE repo's entry:
   after a sweep staged from a worktree fixture, the source key's pending
   count reaches zero and no ledger or scratch artifact exists under the
   worktree's key.
5. `gate-telemetry` reproduces, from fixtures, the metric classes the July
   mining produced by hand (rounds/backstops, degrades by token, fix-cycle
   rate, backlog) in both markdown and `--json`, reporting skipped
   artifacts explicitly.
6. All existing suites and needles stay green; the extended eval scenario
   passes `bun run quorum check` (live run reserved for the human partner).
7. Concurrent-session appends cannot corrupt the ledger (test-proven).

## 9. Risks

- **Agents skip `gate-round`** — prose-orchestrated like every checker;
  mitigated by needles, Red Flags, and micro-tests; escalation paths
  (invocation wrapper, PreToolUse hook) are recorded, not built.
- **Ledger grows unbounded** — events are one line each; even a year of
  heavy use is kilobytes. Revisit only if telemetry shows otherwise (a
  `compact` subcommand is a YAGNI-deferred idea, noted not promised).
- **Sweep meets rebased/garbage-collected history under the same repo
  key** — handled: both range ends validated, `unsweepable` closure with
  attribution. A MOVED repo is a different case: the key derives from the
  absolute git-dir path, so the old ledger is orphaned under the old key —
  the notice will not find it. Accepted (matches every other scratch root's
  behavior on a move); `gate-telemetry --all` still reports orphaned keys'
  backlogs, which is the discovery path if it ever matters.
- **Cache wipe loses pending records** — accepted residual (§6), same
  blast radius as the status quo ante.
- **Worktree-keyed appends orphan when the worktree is removed** —
  accepted residual, recorded at the final whole-branch review: repo keys
  derive from the absolute git-dir, and a LINKED DEVELOPMENT worktree (a
  first-class hyperpowers workflow) has its own git-dir — a gate degraded
  inside one appends under the worktree's key, and removing the worktree
  post-merge strands the entry under an orphan key that no session-start
  notice will surface (`gate-telemetry --all` is the discovery path; the
  `ungated/` root has no GC by design). §4.4 solved this for the sweep's
  own throwaway worktrees; development-worktree appends are deferred with
  two mitigation candidates named for a follow-up: a pending-check in
  finishing-a-development-branch before worktree removal, or keying
  appends off `git rev-parse --git-common-dir` so all worktrees of a repo
  share one ledger.
