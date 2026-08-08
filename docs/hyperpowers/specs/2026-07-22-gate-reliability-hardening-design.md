# Gate Reliability Hardening — Design

Date: 2026-07-22
Status: draft (spec gate pending)
Target release: 6.3.0

## 1. Problem

A mining pass over ~2 months of real hyperpowers usage on this machine
(129 main transcripts across 54 projects, ~1,700 SDD scratch artifacts,
273 Codex doc-gate sessions, 290 review jobs) found that the Codex review
gate's failure handling — not its review quality — is the top reliability
problem:

- **Stale brokers silently kill the gate for whole sessions.** The
  third-party companion (`codex-plugin-cc`, installed as `codex@openai-codex`)
  stores per-repo broker state in
  `~/.claude/plugins/data/codex-openai-codex/state/<repo-key>/broker.json`,
  pointing at a Unix socket under a macOS per-user temp dir. macOS purges
  those dirs (typically overnight); every companion call then fails with
  `connect ENOENT .../broker.sock`, the availability probe reads this as
  terminal, and the session silently downgrades to no-Codex. `broker.sock`
  failures grew from 9 transcript hits in June 2026 to 241 in July; "Codex
  gate unavailable" notices appeared 174 times, almost all infra-forced and
  none attributed to a cause.
- **Silent non-verdicts.** 10 of 273 doc-gate sessions ended with no
  terminal `Verdict:` line (one ran 1,198 s and stopped mid-sentence while
  "formatting the verdict"). The gate doc's treat-missing-verdict-as-
  not-approval rule is prose; prose demonstrably was not enough.
- **Orphaned review jobs from bad base refs.** One `adversarial-review` job
  is stuck "running" forever: its base resolved to the git empty-tree hash,
  `merge-base` fataled inside the companion, and no verdict record was ever
  written.
- **Reviewer bootstrap waste.** 53% of doc-gate Codex sessions spend their
  first tool calls re-reading the `using-hyperpowers` bootstrap (32% as the
  literal first action) — pure overhead for a stateless one-shot reviewer,
  paid again every round.

Constraint that shapes everything: **we do not control the companion.**
It is OpenAI's distribution; all shipping fixes must live in hyperpowers,
degrade cleanly when the plugin is absent, and survive companion-internal
changes (its JSON field paths already changed once between 1.0.5 and 1.0.6).
Upstream issues/PRs are a parallel track; nothing here may depend on them.

## 2. Approach (decided via Codex approach gate)

Selected architecture: **narrow checkers + hook janitor** (proposed by
Codex in the one-shot approach gate; chosen on merits over a hook-only
variant and a monolithic gate-runner script). Keep the prose-driven gate
flow in `codex-review-gate.md` — its review quality is good (81% of
findings real in the mined sample) — but replace each fragile *decision
point* with a small, contract-tested, zero-dependency bash script whose
machine-readable answer is the only trusted input to that decision.
The one responsibility that cannot run in the agent sandbox (repairing
broker state under `~/.claude/plugins/`) moves to the SessionStart hook,
which runs unsandboxed.

## 3. Goals / non-goals

Goals:

1. The dominant broker failure self-heals at session start and compaction,
   and is *attributed* (never silently conflated with "plugin not
   installed") when it strikes mid-session.
2. A missing or malformed review verdict can never be read as an approval —
   enforced mechanically, fail-closed.
3. An invalid base ref can never launch a code review.
4. Stateless Codex reviewer sessions stop loading the hyperpowers bootstrap.
5. Root causes are reported upstream (issues at `openai/codex-plugin-cc`).

Non-goals (deferred to later sub-projects):

- Ungated-work ledger and post-recovery review sweep (sub-project 2).
- Mechanical round-ceiling enforcement and gate telemetry (sub-project 2).
- Review-package and prompt-efficiency changes (sub-project 3).
- Any change that depends on upstream companion modifications.
- Reducing existing human approval points (explicitly out per partner
  direction).

## 4. Components

All new scripts live in `skills/requesting-code-review/scripts/`, bash,
zero external dependencies (no jq), macOS primary / Linux tolerated.
Shared error discipline: **exit 0 for every determinate answer (including
negative ones), JSON on stdout; non-zero exit means the checker itself
failed**, and the gate doc maps checker failure to the conservative
outcome (preflight error → unavailable; base error → do not launch;
normalize error → incomplete).

### 4.1 `broker-health <state-dir>` — shared health predicate

Reads `<state-dir>/broker.json`. Output:
`{"status":"healthy|dead|absent|unknown","reason":"..."}`.

- `healthy`: primary check — a unix-socket connect probe to the record's
  endpoint succeeds (a live listener IS health, pid-independent and
  record-specific). Where the probe is unverifiable (sandbox denies the
  connect, timeout, non-socket path), fall back to: socket file exists
  AND `kill -0 <pid>` succeeds AND, where `ps` is available, the pid's
  command line matches the broker signature
  (`codex|app-server-broker|cxc-`; overridable via
  `HYPERPOWERS_BROKER_CMD_PATTERN` for tests). Never claim dead on an
  unverifiable check.
- `dead`: positive evidence of death — connection refused on an existing
  socket file (no listener), socket file missing, pid not alive, the
  recorded `sessionDir` no longer exists (the macOS-purge signature), or
  the pid's command line shows it was reused by a non-broker process.
- `absent`: no `broker.json` (normal before first companion call — the
  companion self-provisions).
- `unknown`: file exists but is unparseable or missing expected fields
  (e.g., a future companion version changed the schema). **Unknown is
  never treated as dead.**

### 4.2 Session-start janitor (in `hooks/session-start`)

On `startup|clear|compact`, before emitting the bootstrap JSON:

- No-op instantly if `~/.claude/plugins/data/codex-openai-codex/state/`
  does not exist (other harnesses, machines without the plugin).
- For each `state/*/broker.json`: if `broker-health` says `dead`,
  quarantine by renaming to `broker.json.stale-<epoch>`. Never delete;
  never touch `healthy`, `absent`, or `unknown`.
- GC quarantined `broker.json.stale-*` files older than 14 days (matches
  the `sdd-dir` GC policy from commit b838efa).
- All diagnostics to stderr; all failures swallowed — the janitor must
  never break or delay session start, and must never corrupt the hook's
  stdout JSON contract. The sweep is bounded: at most 12 broker records
  and a ~2-second budget per run; stragglers are picked up by the next
  startup/clear/compact run (the quarantine-age GC still runs after an
  early break — it is cheap).

Quarantining a dead broker lets the companion re-provision on the next
call — turning the former session-killing failure into one transparent
reconnect. Sweeping *all* repo dirs (not just the current repo) is safe
because the health predicate is intrinsic to each broker.

### 4.3 `codex-preflight` — attributed availability

Supersedes the §1 probe as the gate's availability check. **It strictly
extends — never weakens — the current probe's readiness semantics**: today
`codex-available.sh` approves only when the companion's `setup --json`
reports ready (plugin present AND Codex CLI installed AND authenticated).
Preflight keeps that bar and adds attribution. Output:

```json
{"status":"ok|not-installed|not-ready|stale-broker",
 "codexPath":"...","codexVersion":"...",
 "reason":"...","recovery":"..."}
```

Check sequence:

1. Resolve the newest installed plugin (as the current probe does) —
   else `not-installed` (current no-Codex behavior, unchanged notice).
2. Locate the current repo's companion state dir (below) and run
   `broker-health` on it — `dead` → `stale-broker`, **checked before
   `setup --json`** because a stale broker makes the setup call itself
   fail with `connect ENOENT`, which is exactly the misattribution this
   spec eliminates.
3. Run `setup --json` — not ready → `not-ready`, with `reason` carrying
   the failing dimension from the setup payload (CLI missing, not
   authenticated, etc.).
4. Otherwise `ok`, carrying `codexPath`/`codexVersion` exactly as the
   current probe does. `broker-health` `healthy`, `absent`, and `unknown`
   all fall through to steps 3–4 (`absent` is normal — the companion
   provisions on demand; `unknown` is hands-off by design).

On `stale-broker`, `recovery` carries the exact one-line shell command
(quarantine rename of that repo's `broker.json`) for the human partner to
run in a terminal, since the agent sandbox cannot write under
`~/.claude/plugins/`. The gate emits the attributed notice with that
command and degrades cleanly if not acted on; the next gate re-runs
preflight, so recovery is picked up automatically. A compaction also
re-triggers the janitor.

**Locating the current repo's state dir** (`broker-state-dir` helper,
shared by preflight; the janitor does not need it — it sweeps all dirs).
The companion derives its per-repo key internally (git-root realpath →
slug → hash, honoring `CLAUDE_PLUGIN_DATA`); reimplementing that hash
would be schema-drift-fragile, so the helper resolves data-driven
instead:

1. State root: `$HYPERPOWERS_CODEX_STATE_ROOT` if set (test/relocation
   override, matching the existing `HYPERPOWERS_*` override convention in
   `codex-available.sh`), else
   `~/.claude/plugins/data/codex-openai-codex/state/`. Hyperpowers
   scripts must NOT read `CLAUDE_PLUGIN_DATA`: that variable identifies
   the *calling* plugin's data dir (the companion appends `state` to its
   own — `lib/state.mjs`), so inside hyperpowers hooks it would point at
   hyperpowers' data dir, never the companion's.
2. Evidence scan first (name-independent): across ALL state
   subdirectories, one whose `state.json` records this repo's git-root
   realpath as a job `workspaceRoot` wins. The companion's own records
   are authoritative, and this finds repos whose basenames the companion
   sanitizes into a different slug (spaces, special characters).
3. Name fallback: candidates are subdirectories named
   `<repo-basename>-<16 hex chars>`; a unique candidate wins.
4. No match, or ambiguity that cannot be resolved → report `absent`
   (**never guess** — a wrong dir must not be health-checked or named in
   a recovery command). A repo with no state dir also has no broker to
   recover, so `absent` is always safe.

`codex-available.sh` is retained as a thin wrapper over `codex-preflight`
preserving its exact current contract (exit 0 + two stdout lines on `ok`;
non-zero for every other status) so external callers keep working
unmodified. Callers that delegate to §1 by reference — the brainstorming
approach gate does — inherit preflight and its per-status notices
automatically when §1 is amended.

### 4.4 `base-ref-ok <base-ref> [repo-dir]` — pre-launch validation

Run before every `adversarial-review` launch. Checks, in order:

1. `git rev-parse --verify --quiet <base-ref>` resolves to a raw object —
   else `unresolvable`.
2. The raw resolved object is not the empty-tree hash
   (`4b825dc642cb6eb9a060e54bf8d69288fbee4904`) — checked **before**
   commit peeling, which would itself reject the empty tree and
   misreport it as `unresolvable`.
3. `git rev-parse --verify <base-ref>^{commit}` peels to a commit —
   else `unresolvable` (non-commit object).
4. `git merge-base <base> HEAD` succeeds — else `no-merge-base`.
5. The resolved base is not HEAD itself — else `empty-range`.

Output: `{"ok":true,"resolvedBase":"<sha>"}` or
`{"ok":false,"reason":"unresolvable|empty-tree|no-merge-base|empty-range"}`.
On `ok:false` the gate must not launch the review; it fixes the base or
degrades with the attributed reason. This closes the forever-"running"
orphan case at the only place we control — before launch.

### 4.5 `verdict-normalize <payload-file>` — fail-closed verdict authority

Input: the captured companion output for a completed review call (task
stdout, or a stored job result fetched via `result`). Knows the payload
field paths for companion 1.0.5 and 1.0.6 plus the
`.storedJob.result.rawOutput` fallback; unrecognized layouts fall through
to raw-text verdict parsing before giving up. Output:

```json
{"result":"approved|blocking|incomplete",
 "verdict":"approve|needs-attention|none",
 "blockingCount":0,
 "reason":"..."}
```

Rules:

- No parseable verdict → `incomplete`. Always.
- Parseable `approve` with zero blocking findings → `approved`.
- `needs-attention`, or any blocking finding, or the contradictory
  approve-with-blocking-findings case → `blocking` (conservative).

Gate-doc amendment (the fail-closed core): **only `verdict-normalize`
output counts as an approval** for the convergence loop's exit rule. On
`incomplete`: where a job id exists, one bounded re-fetch
(`status <job-id> --wait` then `result`) and re-normalize; for foreground
output with no job id there is nothing to re-fetch. If still
`incomplete`, report "Codex review did not complete — not an approval"
and follow the existing not-approval path. The agent still reads the raw findings text to do the actual fixing;
normalization gates only the loop decision.

### 4.6 Reviewer bootstrap suppression (prompt-level)

Mechanism: every review prompt/focus template in the gate docs
(`codex-review-gate.md` spec, plan, and the three code recipes;
`codex-approach-gate.md`) carries a standing line:
"You are a stateless reviewer for this request only; do not load or read
skill bootstraps or skills."

An environment-marker mechanism (setting a variable on companion
invocations and having `hooks/session-start-codex` suppress the bootstrap)
was considered and **rejected**: the companion starts a persistent
per-repo broker with the caller's environment and later calls reuse that
broker, so a marker set by one review could leak into the broker
environment and suppress the bootstrap for later *non-review*
companion-launched sessions (e.g. rescue tasks) in the same repo. A
scoped, per-request review flag is the correct fix and belongs upstream
(issue 3 in §4.8).

Prompt-level suppression is advisory — a reviewer may still read the
bootstrap — but it is leak-free, and the ~53% baseline gives a direct
measure of improvement in future transcript mining.

### 4.7 Gate-doc amendments (`codex-review-gate.md` and callers)

- §1: probe replaced by `codex-preflight`; per-status notices; the
  stale-broker notice includes the recovery command; degrade reasons are
  stated in the notice AND in the §6 hand-back (so future transcript
  mining can attribute every ungated proceed).
- §3 (code gates): `base-ref-ok` is a required pre-launch step; a Red
  Flag entry forbids launching `adversarial-review` without it.
- §4/4b: raw JSON-path extraction prose replaced by the
  `verdict-normalize` call; version-sensitive field-path guidance moves
  into the script where it is fixture-tested.
- §5: convergence loop consumes the tri-state; a Red Flag entry forbids
  treating raw companion output (or absence of output) as approval.
- Every review prompt/focus template gains the stateless-reviewer
  suppression line (§4.6).

### 4.8 Upstream track (parallel, non-blocking)

File five issues at `openai/codex-plugin-cc`:

1. Broker self-heal: discard/re-provision when `broker.json` points at a
   dead socket or missing `sessionDir`.
2. Guarantee a terminal verdict record for every review job (or an
   explicit `incomplete` status) — no silent absence.
3. A supported per-request flag to launch reviewer sessions without skill
   bootstraps (scoped to the request — an env marker is not viable from
   the caller side because the persistent broker inherits and replays the
   provisioning environment; see §4.6).
4. SessionEnd `EPERM ... unlink broker.json` symptom.
5. An invalid `--base` (e.g. the empty-tree hash) makes `merge-base`
   fatal mid-job and orphans the review as `running` forever; validate
   before starting the worker and record `failed` on git fatals.

PRs may follow where welcome, per upstream's contribution process. No
spec item depends on any of these landing.

## 5. Lifecycle after the change

1. Session start / clear / compact → janitor quarantines provably dead
   brokers (any repo).
2. Gate start → `codex-preflight` once per skill run (result reused, as
   today) → `ok` continues; `not-installed`/`stale-broker` emit the
   attributed notice (with recovery command where applicable) and degrade
   exactly as the current no-Codex path does.
3. Code gates → `base-ref-ok` before launch; doc gates skip (no base).
4. Companion invoked foreground (review prompts carry the
   stateless-reviewer line); output captured into the per-run scratch dir
   (existing `codex-review-dir` convention).
5. `verdict-normalize` drives the convergence loop; `incomplete` gets one
   bounded re-fetch then becomes not-approval.
6. §6 hand-back reports Codex version and any degrade attribution.

## 6. Error handling and safety

- Janitor: never blocks/breaks session start; positive-evidence-only
  quarantine; `unknown` schemas untouched; rename-not-delete with 14-day
  GC. A broker actively being provisioned has a live pid and is therefore
  `healthy`-or-`absent`, never quarantined.
- Checkers: determinate answers exit 0; internal failure exits non-zero
  and maps to the conservative outcome. The cure can never be worse than
  the disease: every new failure path lands in the existing, well-tested
  degrade lane rather than a new one.
- Companion evolution: field-path knowledge is concentrated in
  `verdict-normalize` with per-version fixtures; `broker-health` treats
  schema drift as `unknown` (hands off).
- Sandbox boundaries respected: reads from the sandbox, writes only from
  hooks; mid-session repair is delegated to the human partner via an
  exact command, consistent with the conservative-on-automation
  direction.

## 7. Testing

- **Checker unit tests** (bash, `tests/`): fixture matrices —
  `broker.json` healthy / dead-pid / missing-socket / purged-sessionDir /
  malformed / absent; `setup --json` ready / not-ready per failing
  dimension (CLI missing, unauthenticated); `broker-state-dir`
  resolution against a fixture state tree (unique match, `state.json`
  disambiguation, ambiguous → `absent`, and a
  `HYPERPOWERS_CODEX_STATE_ROOT` override fixture);
  payloads 1.0.5 / 1.0.6 / malformed / missing verdict /
  approve-with-blocking-findings; git fixtures: unresolvable ref,
  empty-tree base, no merge-base, base==HEAD.
- **Janitor test**: fake state tree in `$TMPDIR`; quarantine matrix, GC
  aging, stdout-purity (hook JSON unaffected), no-op speed when state dir
  absent.
- **Contract tests**: new needles in `tests/codex-review-gate/` for the
  §1/§3/§4b/§5 amendments and both new Red Flags.
- **Eval scenarios** (`evals/`, stub companion): (a) new
  stale-broker-attributed-degrade scenario — gate fires, preflight
  reports `stale-broker`, agent emits the attributed notice with the
  recovery command and proceeds degraded without fabricating a verdict;
  (b) existing `codex-gate-incomplete-not-approval` must pass unchanged
  through the new mechanical path; (c)
  `codex-gate-converges-on-reraise` must pass unchanged (regression guard
  on the convergence loop).
- **Wording micro-tests** per `writing-skills` discipline for the
  reworded gate sections before full scenarios.
- **Live verification** during implementation: one end-to-end gate on
  this repo with the amended doc.

## 8. Acceptance criteria

1. With a fabricated dead broker in a test state dir, a new session's
   janitor quarantines it and a subsequent preflight reports `ok` (broker
   absent; the companion re-provisions on its next call); with a live-pid
   broker, nothing is touched.
2. `codex-preflight` distinguishes `not-installed` vs `not-ready` vs
   `stale-broker`; the gate notice for each is distinct and (for stale)
   actionable; a `setup --json` ready:false environment can never yield
   `ok` (no weakening of the current probe's readiness bar); and
   `broker-state-dir` never returns a wrong directory (ambiguity resolves
   to `absent`).
3. No path exists in the amended gate doc by which a review lacking a
   parseable verdict reaches an "approved" outcome; the incomplete eval
   passes via `verdict-normalize`.
4. `adversarial-review` cannot be reached in the amended gate doc without
   a prior `base-ref-ok` pass; empty-tree and no-merge-base fixtures are
   rejected.
5. Every review prompt/focus template in the amended gate docs carries
   the stateless-reviewer suppression line, and the spec documents why
   env-marker suppression is rejected (shared-broker environment leak).
6. All existing gate contract tests and the two existing gate eval
   scenarios still pass.
7. Five upstream issues filed (with user approval) and their URLs
   recorded in the plan document's upstream task section.

## 9. Risks

- **Prompt-level suppression is advisory** — a reviewer may ignore the
  line and read the bootstrap anyway; accepted (leak-free beats
  airtight-but-leaky), measurable against the ~53% baseline, with the
  scoped upstream flag as the real fix.
- **Companion schema drift** — concentrated in fixture-tested scripts;
  `unknown` is hands-off by design.
- **Quarantine race with an active broker** — excluded by the
  positive-evidence predicate (live pid ⇒ never quarantined).
- **Checker mis-sequencing by the agent** (the known weakness of this
  architecture vs. a monolithic runner) — mitigated with contract-test
  needles, Red Flags, and eval scenarios; if evals show sequencing
  drift, the escalation path is consolidating the checkers into a single
  gate-runner script (the runner-up approach) without changing their
  contracts.
