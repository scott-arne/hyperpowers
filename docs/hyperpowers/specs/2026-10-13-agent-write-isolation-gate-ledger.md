# Agent Write Isolation — Spec Gate Ledger

Companion to `2026-10-13-agent-write-isolation-design.md`. It records what seven
Codex spec-gate rounds found across four candidate mechanisms, and why each
earlier mechanism was abandoned. It is committed because the design's argument
is only legible alongside the escapes that killed its predecessors; the gate
directories it was assembled from live under the user cache and are scratch.

Rounds ran two lenses each, completeness-and-consistency and
feasibility-and-scope, against the evals checkout at `b6a923a31` and the
Gauntlet fork at `a35607e`.

| Gate directory | Mechanism | Rounds |
|---|---|---|
| `run-9mS9vkz7` | 1: relocate the workspace, sandbox at `--target` | 1 |
| `run-aqo9pen3` | 2: confine the tmux server (Seatbelt / Landlock) | 3, then backstop |
| `run-lSJ1k4D3` | 2, continuation round | 1 |
| `run-vyhdnUg2` | 3 and 4: privilege separation, then container-scoped | 4, then backstop |
| `run-LQS5RgE1` | 4, continuation rounds | 3 |

---

## Mechanism 1 — sandbox at Gauntlet's `--target`

## Round 1 (lenses: completeness-and-consistency, feasibility-and-scope)

Both lenses `needs-attention`. Converged critical finding: `--target` is not the
Coding-Agent launch boundary. Gauntlet's TUI adapter ignores `target` when
starting tmux and uses it only in prompt text; the real launch is
`evals/coding-agents/<agent>-context/launch-agent`, which execs the CLI directly.
The spec's central decision therefore does not hold.

Second critical (completeness lens): Gauntlet starts the private tmux server
BEFORE the wrapper, so it is an unsandboxed ancestor rather than a descendant. A
sandboxed agent can reach its socket and delegate a write (`tmux run-shell`),
escaping the profile. The spec's probe and attestation cannot detect this.

Further blocking findings, both lenses converging on most:
- The container cannot drop UID: `evals-container` launches with
  `--user $(id -u):$(id -g)`, so quorum, Gauntlet and the wrapper already share
  one non-root host UID.
- No lifecycle owner guarantees handover and attestation on every exit; SIGINT
  signals only the direct child, writes a verdict and exits.
- The handover omits real workspace entries (sibling `coding-agent-workdir-*`
  directories) and leaves absolute paths stale for capture, OpenCode export,
  Antigravity aliases and post-checks.
- `--out-root` makes `results/` not the only record root.
- Stage 1 is NOT behaviour-neutral: the agent observes a different absolute cwd,
  recorded in transcripts, and the hidden `.workspaces` component forces
  Antigravity down its visible-symlink path.
- The orphan sweep's age rule can delete a live workspace (scenarios exceed the
  60-minute default; nested writes do not refresh the root mtime).
- The adversarial test is too shallow: no symlink, hard-link, canonical-path,
  retained-descriptor or surviving-descendant probes.
- The `isolation` verdict contract is unspecified.

Status: NOT a round-2 patch. Two load-bearing facts in the approved design are
false. Returned to the human partner for a design decision rather than iterated
in the fix loop.

---

## Mechanism 2 — confine the tmux server

Spec: docs/hyperpowers/specs/2026-10-13-agent-write-isolation-design.md
Gate dir: run-aqo9pen3. Ceiling 4.

## Round 1 (lenses: completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`. Converged on two criticals.

**C1 — non-descendant confused deputies (re-opens decisions 3 and 5).** Both
lenses. Seatbelt's default-allow profile confines descendants but does not stop
the agent connecting to OTHER unconfined same-UID execution brokers: a
pre-existing user tmux server on another socket, launchd, the docker socket.
Probe 10 only covers the newly confined server. Container is not affected (no
other same-UID brokers exist there). Escalated to the human partner rather than
fixed in the loop, because it re-opens an adjudicated decision.

**C2 — the Gauntlet enforcement chain is writable and undenied.** Both lenses.
The deny set covers evals and hyperpowers but not the Gauntlet checkout or the
user-writable shim at ~/.local/bin/gauntlet that quorum actually execs. An agent
can poison either so a later or concurrent run starts unconfined. The
"compromised Gauntlet" out-of-scope line is circular when the in-scope adversary
is the one compromising it. Spec fix, no decision needed.

## Highs, all spec gaps to fix in round 2

- Landlock needs a complement-of-UNION over all denied roots (a prefix trie),
  not a per-root complement: `/workspace/evals` and `/workspace/superpowers` are
  disjoint and unioning their complements re-allows both.
- "Write" has no mutation-rights contract. The measured probe was append only.
  Must enumerate Seatbelt operations and Landlock handled rights: truncate,
  create, unlink, rename/refer, link; and probe delete, rename-out, rename-in,
  atomic replace.
- Policy ownership is circular: evals is assigned generation, but gauntlet mints
  the runId and so the concrete scratch path only at `start()`. Needs a
  specialization-and-attestation contract returning the applied digest.
- Confinement failure has no machine-readable transport: an adapter throw
  becomes gauntlet's generic exit 1, and quorum discards the exit code and
  synthesizes `investigate`. Needs a typed code or sidecar.
- Provenance ordering: provenance is captured and handed to the SIGINT handler
  before setup; the policy digest only exists after. Needs a two-stage lifecycle.
- The control arm contradicts decision 4: the spec bans unconfined completed
  runs and then requires ten of them. Must pin the control to pre-change
  revisions rather than add an opt-out.
- `--out-root` uses lexical resolve, not canonicalization; symlinked roots and
  container bind aliases are unprobed.

Medium: the `--sandbox-profile` flag is underspecified (two formats, one flag);
hard-link and descriptor probe timing is ambiguous about before/after
confinement.

## Rounds 2 and 3, and the backstop

Round 2: 1 critical (PATH shadowing of the Gauntlet launcher) plus 9 findings.
All fixed in the spec; no decision re-opened. Recorded in adjudications.md.

Round 3: 3 criticals plus 5 findings, all real and all newly surfaced:
- the enforcement chain stopped at the shim and omitted `bun` and `tmux`, both
  owner-writable on this host;
- Seatbelt `file-write*` does not cover hard links, so `file-link` was missing;
- publishing the attestation was not a barrier, since `adapter.start()` returns
  straight into `runAgent()`.
All fixed in the spec, plus the terminal-record classification, concrete wire
constants, a predeclared release acceptance rule, positive controls on every
denial probe, the `pending` definition, and launch-cwd-derived carve-backs.

## Backstop

`gate-round` returned `backstop` at round 4 of ceiling 4. Per the Red Flag in
gate-fix-loop.md §5, Codex was NOT invoked again for this gate.

State at hand-back:
- Still-open blocking findings: none. Every finding raised across three rounds
  was confirmed and fixed; none was declined, and none was accepted as risk.
- The gate never returned `approve`. It ran out of rounds with everything
  addressed rather than converging.
- **The round-3 fixes ship unreviewed by Codex.** This is a document gate, so
  there is no Claude reviewer pass or test run standing behind them either.
  The only verification they have is the author's own self-review.
- The `ungated-ledger --class backstop-fix` append does not apply: that path
  takes a commit range, and this spec is uncommitted with no base/head.

Signal worth carrying to the human partner: the critical count per round went
2, 1, 3. The finding rate is not decaying, and each round's criticals were
genuinely new holes rather than restatements, which argues the surface is still
yielding.

### Continuation round

Spec: docs/hyperpowers/specs/2026-10-13-agent-write-isolation-design.md
Gate dir: run-aqo9pen3. Ceiling 4.

## Round 1 (lenses: completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`. Converged on two criticals.

**C1 — non-descendant confused deputies (re-opens decisions 3 and 5).** Both
lenses. Seatbelt's default-allow profile confines descendants but does not stop
the agent connecting to OTHER unconfined same-UID execution brokers: a
pre-existing user tmux server on another socket, launchd, the docker socket.
Probe 10 only covers the newly confined server. Container is not affected (no
other same-UID brokers exist there). Escalated to the human partner rather than
fixed in the loop, because it re-opens an adjudicated decision.

**C2 — the Gauntlet enforcement chain is writable and undenied.** Both lenses.
The deny set covers evals and hyperpowers but not the Gauntlet checkout or the
user-writable shim at ~/.local/bin/gauntlet that quorum actually execs. An agent
can poison either so a later or concurrent run starts unconfined. The
"compromised Gauntlet" out-of-scope line is circular when the in-scope adversary
is the one compromising it. Spec fix, no decision needed.

## Highs, all spec gaps to fix in round 2

- Landlock needs a complement-of-UNION over all denied roots (a prefix trie),
  not a per-root complement: `/workspace/evals` and `/workspace/superpowers` are
  disjoint and unioning their complements re-allows both.
- "Write" has no mutation-rights contract. The measured probe was append only.
  Must enumerate Seatbelt operations and Landlock handled rights: truncate,
  create, unlink, rename/refer, link; and probe delete, rename-out, rename-in,
  atomic replace.
- Policy ownership is circular: evals is assigned generation, but gauntlet mints
  the runId and so the concrete scratch path only at `start()`. Needs a
  specialization-and-attestation contract returning the applied digest.
- Confinement failure has no machine-readable transport: an adapter throw
  becomes gauntlet's generic exit 1, and quorum discards the exit code and
  synthesizes `investigate`. Needs a typed code or sidecar.
- Provenance ordering: provenance is captured and handed to the SIGINT handler
  before setup; the policy digest only exists after. Needs a two-stage lifecycle.
- The control arm contradicts decision 4: the spec bans unconfined completed
  runs and then requires ten of them. Must pin the control to pre-change
  revisions rather than add an opt-out.
- `--out-root` uses lexical resolve, not canonicalization; symlinked roots and
  container bind aliases are unprobed.

Medium: the `--sandbox-profile` flag is underspecified (two formats, one flag);
hard-link and descriptor probe timing is ambiguous about before/after
confinement.

## Rounds 2 and 3, and the backstop

Round 2: 1 critical (PATH shadowing of the Gauntlet launcher) plus 9 findings.
All fixed in the spec; no decision re-opened. Recorded in adjudications.md.

Round 3: 3 criticals plus 5 findings, all real and all newly surfaced:
- the enforcement chain stopped at the shim and omitted `bun` and `tmux`, both
  owner-writable on this host;
- Seatbelt `file-write*` does not cover hard links, so `file-link` was missing;
- publishing the attestation was not a barrier, since `adapter.start()` returns
  straight into `runAgent()`.
All fixed in the spec, plus the terminal-record classification, concrete wire
constants, a predeclared release acceptance rule, positive controls on every
denial probe, the `pending` definition, and launch-cwd-derived carve-backs.

## Backstop

`gate-round` returned `backstop` at round 4 of ceiling 4. Per the Red Flag in
gate-fix-loop.md §5, Codex was NOT invoked again for this gate.

State at hand-back:
- Still-open blocking findings: none. Every finding raised across three rounds
  was confirmed and fixed; none was declined, and none was accepted as risk.
- The gate never returned `approve`. It ran out of rounds with everything
  addressed rather than converging.
- **The round-3 fixes ship unreviewed by Codex.** This is a document gate, so
  there is no Claude reviewer pass or test run standing behind them either.
  The only verification they have is the author's own self-review.
- The `ungated-ledger --class backstop-fix` append does not apply: that path
  takes a commit range, and this spec is uncommitted with no base/head.

Signal worth carrying to the human partner: the critical count per round went
2, 1, 3. The finding rate is not decaying, and each round's criticals were
genuinely new holes rather than restatements, which argues the surface is still
yielding.

## Round 4 (continuation gate, authorized by the human partner as an extra spend)

Confirmed fixed by both lenses: the Seatbelt `file-link` rule, the two-way
commit barrier, failure classification, wire constants, acceptance criteria,
positive controls, and `pending` semantics.

Three new criticals, two of which re-open adjudicated decisions:

1. **Post-agent verification executes agent-controlled code unconfined.** After
   Gauntlet exits, quorum runs post-check commands such as `npm test` against
   agent-written files (`src/checks/index.ts:62-100`;
   `src/check/fs-verbs.ts:268-282`;
   `scenarios/sdd-spec-constraint-preserved/checks.sh:11-17`), inheriting
   `QUORUM_RUN_DIR` and `QUORUM_RECORD_SINK`. Agent-authored code therefore
   runs as the trusted process with the record sink in its environment. Breaks
   the host guarantee AND the categorical container guarantee. Not an
   unenumerated broker: a deterministic harness-owned execution path.
2. **The enforcement chain still leaks through PATH.** The shim is
   `#!/usr/bin/env bash` with bare `exec bun`; Gauntlet invokes bare `ps`;
   quorum invokes bare `bash` after agent writes begin. None of `env`, `bash`,
   `ps` are in the pinned chain, and nothing in scope can make a shebang
   absolute. Also: the host PATH has nonexistent entries ahead of the shim,
   which the "canonicalize or abort" rule would reject.
3. **My overlap rule is self-contradictory.** The workdir is necessarily
   beneath the protected output root, so "abort when a carve-back overlaps any
   protected root" aborts every normal run. A plain logic error introduced in
   round 3.

Re-opening adjudicated decisions:

- **Decision 7 (host IPC).** `tmux -S <path>` accepts an arbitrary socket path
  and `run-shell` executes `/bin/sh` in the server, so denying
  `$TMUX_TMPDIR/tmux-<uid>/` cannot cover even the one broker it names. The
  enumeration is structurally incapable, not merely incomplete.
- **Decision 6 (container matches host intent).** Landlock has no rights for
  `chmod`, `chown`, `utimes` or xattrs, while the Seatbelt contract covers
  mode, owner, times and flags. Under one UID the agent can still mutate record
  metadata in the container, so the container claim is not categorical either.

Pattern: criticals per round 2, 1, 3, 3. Not decaying. Rounds 3 and 4 each
found genuinely new classes rather than restatements.

Observation carried to the human partner: all three round-4 criticals collapse
under privilege separation, the alternative declined at decision 7. A distinct
agent UID means post-check code running as that UID cannot write the record,
`chmod` fails for want of ownership, and a user-owned tmux socket refuses the
connection. The mechanism was chosen before any of these three paths was known.

---

## Mechanisms 3 and 4 — privilege separation

This is the third mechanism for this sub-project. The spec's Supersession
section records the first two and why each failed; that history is adjudicated
context, not open ground. Do not propose returning to Seatbelt/Landlock
confinement of the tmux server without addressing the six escapes listed there.

## Decisions

1. **Threat model: adversarial capability.** The Coding-Agent will write
   anything reachable if that looks like success. (Declined: careless only.)
2. **Both environments** must carry the guarantee. (Declined: host only;
   container only.)
3. **Mechanism: privilege separation**, chosen 2026-10-14 after four spec-gate
   rounds against tmux confinement produced criticals at a rate of 2, 1, 3, 3
   with no decay, each round a new class. The deciding finding was that quorum
   itself runs post-check commands such as `npm test` against agent-written
   files with the record sink in their environment, which no confinement of the
   agent's own process tree can address. Also declined earlier, and still
   declined: an attested record plane, because under a same-UID adversary the
   broker's key is reachable.
4. **Failure is fatal.** No opt-out, no unseparated-but-completed state.
   (Declined: run unseparated and record it; abort with an opt-out flag.)
5. **No host fallback.** Host runs abort until an administrator creates the
   agent account and the sudoers entry. Seatbelt is NOT retained as a weaker
   second host mechanism. (Declined: keep Seatbelt as best-effort host
   hardening; scope the project to the container and leave the host as-is.)
   The human partner chose this knowing it makes the container the only working
   environment until the account exists.
6. **Verification:** deterministic probes in both environments, three live
   smokes (Claude, Codex, Antigravity), one paired control arm at n=10 per arm
   pinned to pre-change revisions. (Declined: smokes only; all eight families.)
7. **One plan across the three repositories.** (Declined: split Gauntlet and
   evals plans; defer the container.)

## Facts established by measurement or inspection during design

- Gauntlet's TUI adapter ignores `--target`: `async start(_target: string)`.
- The Coding-Agent is launched by the Gauntlet-Agent typing
  `"$QUORUM_LAUNCH_AGENT"` into a tmux pane, so the launcher is advisory, and
  failing to use it is the already-detected `qa-agent-misconfigured` mode.
- The pane's cwd is a sibling of the Gauntlet-Agent's `result.json`, and quorum
  discards gauntlet's exit code in favour of that file.
- `scripts/evals-container:443` passes `--user "$(id -u):$(id -g)"`, which is
  what previously made a second container identity impossible. This design
  removes it.
- The host account `johnss51` is **not** in the `admin` group (groups: staff,
  everyone, localaccounts, _developer, sharepoint, _lpoperator), which is why
  the host account is a prerequisite rather than part of the implementation.
- Post-checks execute agent-authored content: `command-succeeds` runs inner
  commands in the agent workspace, and git verbs would run agent-planted
  `.git/hooks/*`.

## Round 1 outcome and the scope decision it produced

Both lenses returned `needs-attention`; the feasibility lens stated the
privilege-separation direction is appropriate. Six design-level repairs were
raised. One was already solved during the round; the rest drove a scope
decision.

**Decision 3 revised (new): container only.** Four of the five remaining
repairs are cheaper or moot when the work targets the container, because we
build the image. Declined, with the human partner told what each costs:
specifying both environments, which needs an administrator-created account on a
machine where `johnss51` is not in the `admin` group and leaves host runs
blocked either way; and pausing the sub-project. Host runs keep today's
behaviour and the verdict says so.

How each round-1 critical is resolved:

- **tmux cross-UID client.** Solved by keeping the tmux server with the harness
  and dropping only the pane's shell. tmux 3.8 makes sockets owner-only, so this
  also closes `run-shell` delegation on a filesystem permission rather than on
  an enumeration `tmux -S` could defeat. Gauntlet's client calls and Antigravity
  teardown are unchanged.
- **Container privilege topology.** An explicit root broker: two root-owned
  scripts invoked through `sudo` with an image-installed `NOPASSWD` rule, rather
  than a bespoke setuid binary. The `docker exec` entrypoint problem disappears
  because nothing depends on the entrypoint.
- **Host reclaim authority.** Moot: `quorum-reclaim` runs as root in the
  container. This was the repair that could not be made on macOS.
- **Root-directory modes insufficient.** Three handoff rules added: provisioned
  content staged with the run's agent group at `0640`/`0750`, no launcher
  sourcing a file outside the run tree (Kimi), and umask `0027` in the broker so
  harness capture can read agent-created transcripts.
- **Cross-run tampering.** A pool of per-run agent accounts; the harness is in
  every agent group, each agent in only its own. This also makes reaping
  complete by account, which no double-fork escapes, replacing the ancestry walk
  that loses reparented descendants.
- **Git executes agent-configured code.** The boundary is the identity, not a
  list of config keys: every `git` invocation against an agent-controlled
  repository runs through the broker, since `core.fsmonitor` and friends defeat
  `core.hooksPath=/dev/null`.

Also fixed: the attestation now carries and validates effective uid, gid and the
full supplementary group vector; the terminal-failure vocabulary is closed with
no open suffix and is written at the earliest CLI boundary that knows the run
directory, so pre-adapter failures produce one; absent-flag behaviour is
specified; the broker closes descriptors above stderr before exec; and the probe
matrix is Linux-only, which removes the unsatisfiable macOS controls.

## Round 2 outcome

Both lenses `needs-attention`; no finding re-opened an adjudicated decision, so
all were fixed in the spec without escalation.

- **Atomic lease.** `<outRoot>/.isolation-leases/` at `0700` harness-owned,
  `O_EXCL` acquisition, run/pid/timestamp binding, release only after the final
  reap and reclaim. A dead owner's account is proven empty before reuse, and an
  account that cannot be proven empty is quarantined permanently.
- **Broker authorization.** The sudoers principal is the harness account only;
  each script re-verifies its real uid and cross-checks arguments against the
  trusted lease. An agent is refused all three scripts with any arguments. This
  closes the cross-run escape where an agent could call `quorum-agent-exec`
  with another run's account.
- **Privileged reap.** A third script, `quorum-reap`, with TERM/KILL and
  rescan-until-empty rather than a raceable one-shot scan; failure to prove
  emptiness quarantines the account and fails closed. Harness-identity Gauntlet
  cannot signal another uid, which is why this is privileged.
- **Populated handoff.** Recursive, non-symlink-following handover of the launch
  cwd and setup-created siblings including `.git`, after setup and pre-checks.
  Gauntlet assigns the scratch directory's group and mode inside `start()`,
  since it creates it after quorum's preflight.
- **Container bootstrap.** `USER quorum` in the image so `docker run` and
  `docker exec` both land on the harness; the synthetic `/etc/passwd` and
  `/etc/group` mounts removed because they would hide the image accounts;
  preflight asserts quorum, Gauntlet and tmux are not root.
- **Attestation pid.** `#{pane_pid}` is the `sudo` wrapper. Replaced with a
  readiness record the broker writes while still root, naming the pid it will
  exec in place, verified by Gauntlet against `/proc/<pid>/status`.
- **`QUORUM_RUN_DIR` is kept, not scrubbed** — two shipped scenarios reference
  it inside single-quoted inner commands and would deterministically fail.
  Keeping it is safe because ownership, not secrecy, protects the record.
- **Environment is an allowlist**, not a two-variable scrub: brokered commands
  get `PATH`, `HOME`, `TMPDIR`, `LANG`, `QUORUM_RUN_DIR`, `QUORUM_WORKDIR` and
  nothing else, so provider keys and credentialed proxy settings are not handed
  to agent-authored tests.
- **The trusted-tooling invariant** is stated once rather than enumerated: a
  harness-identity process never runs with an agent-controlled cwd and never
  loads configuration from an agent-controlled path. Named instances: post-check
  `bun` reading a planted `bunfig.toml` preload, and OpenCode capture running
  against agent-writable config.
- **Umask corrected to `0007`** and capture no longer depends on it: the reclaim
  is staged so `<runDir>/home` becomes harness-owned before capture, which works
  for transcripts written at an explicit `0600`.

Two design facts were measured in a container during this round rather than
assumed, and are recorded in the spec's Evidence section: the ten-way denial set
holds under plain POSIX ownership including hard links and metadata, and umask
`0027` prevents harness cleanup of agent-created directories.

## Round 3 outcome

No criticals — the severity ceiling dropped to High for the first time across
either mechanism. Seven findings, several of them contradictions introduced by
my own round-2 edits rather than design faults. All fixed; none re-opened an
adjudicated decision.

- **Three scripts, consistently.** Round 2 added `quorum-reap` but left the
  identity table, preflight, Dockerfile list, probe and assumption saying two.
  All now name three, and the negative sudo control is a fourth unauthorized
  command.
- **Broker caller verification corrected.** A command run under `sudo` has root
  as its real uid, so the round-2 "verify real uid is the harness" rule would
  have rejected every authorized call. Replaced with root effective identity
  plus `SUDO_UID` compared against the configured harness uid.
- **Readiness record fully specified** and reconciled with the barrier: explicit
  path argument (preflight passes a throwaway path, since it invokes the same
  broker), per-launch nonce, schema, atomic write, deletion before spawn, and a
  30 s wait. Every instruction to attest `#{pane_pid}` is gone.
- **`QUORUM_AGENT_CONFIG_DIR` added to the allowlist**; shipped post-checks
  resolve paths through it and would have inspected an empty path. The plan
  enumerates every `command-succeeds` use to confirm the list is complete.
- **OpenCode export moved before the staged reclaim.** It must run as the agent
  identity to read owner-only session state, so it cannot run after ownership
  moves; it now runs between the first reap and the home reclaim.
- **Reclaim split into `--stage` and `--final`.** `chown` alone left the agent
  group and `2770` modes, so the next holder of the same pool account would
  inherit write access. `--final` strips group write; a sequential-reuse probe
  pins it.
- **One lifecycle owner.** Lease ownership is a single `finally`-style boundary
  covering every exit after acquisition: reap, reclaim `--final`, then release;
  retain and quarantine if either cannot be proven. Without it the finite pool
  drains on the failure paths.
- **Leases moved to `/var/lib/quorum/leases`.** Under the out-root they sat on a
  bind mount and would have outlived the container whose accounts they describe.
- **Handoff semantics made exact**: group set, directories `2770`, files `0660`
  preserving execute bits, symlinks not followed, and an abort if any canonical
  path escapes the tree.

## Round 4 outcome — backstop reached

`gate-round` returned round 4 of ceiling 4. No criticals for the second round
running, and the feasibility lens confirmed seven prior repairs are present:
the three brokers, `SUDO_UID` authorization, the readiness nonce and PID
attestation, environment allowlisting, OpenCode ordering, final group-write
stripping, and container-only scope.

Ten High findings remain. One was fixed in the backstop round because it was a
single word: the identity table still said "two" broker scripts, which is the
round-3 consistency repair genuinely not having landed in that one place. That
fix ships without a confirming Codex pass.

The other nine are carried to the hand-back as **unresolved**, per the backstop
rule that a non-trivial fix raised in the backstop round buys no confirming
review:

1. Crash recovery reallocates an account before reclaiming its previous run.
2. The staged reclaim makes required post-check paths inaccessible (both lenses
   raised this; brokered post-checks lose the run home once it is harness-owned).
3. The ordering barrier is not race-free or launch-bound end to end.
4. Privileged reclaim lacks descendant symlink-safety requirements.
5. Setup-created home content is omitted from the handoff.
6. The current SIGINT exit bypasses the promised lifecycle owner.
7. The canonical-path handoff rule conflicts with shipped external symlinks.
8. Container removal loses the only authority able to reclaim persistent
   agent-owned trees on the bind-mounted results tree.
9. (companion to 2) The run home's accessibility window is contradictory
   between capture and post-checks.

Assessment: converging but not converged. Criticals went 5, 3, 0, 0 across this
mechanism's rounds, and the open items are lifecycle and permission-window
contradictions rather than new escape classes. Finding 8 is the one with an
operational edge: it can strand agent-owned files on the host.

## Round 4 fixes (applied after the backstop, authorized as an extra gate)

The human partner authorized one further gate rather than shipping nine
unreviewed fixes. All nine round-4 Highs are addressed:

- **Crash recovery** now reclaims the lease-recorded run directory after
  reaping and before removing the lease; reaping alone left a `2770`
  group-owned tree for the next holder.
- **The staged reclaim is gone.** It made the home untraversable by the agent
  while shipped post-checks inspect it. Replaced by a fourth broker script,
  `quorum-capture-stage`, which copies capture sources into a harness-owned
  staging directory as root. Ownership of the live tree does not move until the
  final reclaim, so capture reads `0600` transcripts and post-checks keep
  access.
- **Barrier race and nonce.** Gauntlet now polls `/proc/<pid>/status` until the
  credentials appear, instead of reading once while the broker may still be
  root. The nonce is quorum-generated and carried through all four records, so
  the attestation itself is authenticated rather than only the readiness
  record. All four paths are deleted and verified before spawn.
- **Reclaim symlink safety.** Both traversing scripts walk
  descriptor-relative and no-follow (`O_NOFOLLOW`, `AT_SYMLINK_NOFOLLOW`),
  never modify symlink targets, and fail closed on escapes.
- **Setup-created home content** is covered: `setup.sh` runs with umask `0007`
  beneath the setgid home, and the recursive handoff applies to the home too.
- **SIGINT is in scope.** `src/cli/index.ts` currently exits immediately,
  bypassing every finalizer. It becomes an awaited cancellation; a second
  signal forces exit and quarantines.
- **The symlink handoff rule** uses an explicit `lstat` branch and `lchown`,
  because canonicalizing targets would abort every run shipping
  `.agents/skills/superpowers`, which points outside the tree by design.
- **Container removal** is handled by root-owned startup reconciliation: before
  any account becomes leasable, every out-root subtree owned or group-owned by
  a pool account is reclaimed. `down` refuses to remove a container holding an
  active lease unless told to reconcile. A `down`/`up` interruption probe is
  required.
- **Script count** is consistently four everywhere, and the one-word identity
  table error from round 4 is fixed.

## Round 5 outcome

Six Highs, no criticals for the third round running; both lenses confirmed the
round-4 repairs are present. All six fixed.

- **Nonce** added to all four record schemas, with both readers validating it,
  and per-record mismatch and late-record tests.
- **In-flight broker.** `quorum-agent-exec` is root between publishing
  readiness and dropping, so a reap that scans only the agent uid can see an
  empty set while a paused broker is about to drop into a just-released
  account. Broker pids are now registered in the lease atomically before
  invocation; `quorum-reap` terminates and waits for them before scanning; and
  the broker revalidates the lease immediately before dropping.
- **Startup reconciliation** became a real privileged operation,
  `quorum-reconcile <outRoot>`, the single lease-less mode, with a per-out-root
  lock and a completion marker preflight requires. Because `--out-root` is a
  runtime value it runs on demand before the first lease for that out-root, and
  the entrypoint pre-runs it for the default.
- **Capture staging replaced by in-place ownership.** `quorum-capture-own`
  chowns the manifest-named source files where they are. The copy design broke
  Kimi's `sessionDir` and Copilot's `expectedEventsLog`, which key on live
  paths; owning in place moves nothing. The manifest carries each family's
  auxiliary files, such as Kimi's `session_index.jsonl`, which falls outside its
  glob. Capture modules are now in scope.
- **Home handoff precedence** stated: the credential manifest beats the generic
  recursive rule, a family refusing a group-readable credential gets an
  agent-owned `0600` file placed by the broker, and external anchors (AWS, ADC,
  token-cache symlinks) are copied into the run home and their references
  rewritten rather than `lchown`ed.
- **Two environment policies.** `sudo` resets the environment, which would strip
  the proxy and runtime variables a container agent needs before evaluation
  starts; the initial launch is built from a harness-owned validated manifest,
  while post-check inner commands keep the tighter allowlist. Both are tested
  for required presence and forbidden absence.

Script count is now five and consistent throughout.

## Round 6 outcome — the spec was rewritten rather than patched again

Twelve Highs, no criticals for the fourth round. Several were contradictions
that patch-on-patch editing had introduced rather than design faults: the
script count was still inconsistent, verification still named the known-broken
`0027` umask, and `reclaim` was described with two incompatible interfaces.
The document was therefore rewritten once, from the settled design, so the
contradictions stop regenerating. Every round-6 finding is addressed:

- **One broker, `quorum-broker`, with verbs** replaces the five drifting
  scripts and their five sudoers entries. The multi-script surface had gone out
  of sync between definition, preflight, Dockerfile, sudoers and probes in
  three consecutive rounds; a single script with a verb table cannot.
- **Broker API expresses its contexts.** `exec` takes
  `--policy launch|postcheck`, so the two environment policies are selectable
  rather than implied, and `place-credential` exists so an agent-owned `0600`
  credential has an actual placement path — harness code cannot chown to an
  agent account.
- **Linearization is a lease state field.** `exec` registers its own pid as its
  first action (it cannot be pre-registered: the process does not exist until
  tmux invokes it), `reap` sets the lease `draining` before scanning, and `exec`
  re-validates before dropping. Registrations retire on exit, so a stale pid is
  never signalled later.
- **Capture readability fixed properly.** Owning the files was not enough: a
  CLI can write a `0600` transcript inside a `0700` directory it created, which
  the harness cannot traverse. `capture-own` now also makes ancestors
  traversable. The in-place approach is kept because a staging copy breaks
  Kimi's `sessionDir` and Copilot's `expectedEventsLog`.
- **Reconciliation is coherent:** the single lease-less verb, with a per-out-root
  lock and a marker stamped with the **container boot id**. Leases and markers
  from an earlier boot are stale, which is what makes `up` on a *stopped*
  container safe — the previous text covered only removal and recreation, while
  stopping preserves `/var/lib/quorum` and its now-meaningless pids.
- **Container identity** stated once: no `--user`, `USER quorum` in the image,
  synthetic passwd/group mounts removed, preflight asserts the harness identity
  and not root.
- **Umask** is `0007` everywhere; the stale `0027` reference is gone.
- **Credential assumption widened** to cover families outside the three smokes
  and rotating OAuth refresh, with a per-family read-and-refresh probe.

The rewrite also shortened the document from roughly 870 lines to 650 by
removing the accumulated restatements.

## Round 7 outcome — escalated to the human partner

The rewrite cleared most of round 6, but both lenses returned a **critical of my
own making**: the `draining` lease state blocks the specified phase order.
`reap` runs at step 1 and sets `draining`; the brokered OpenCode export at step
2 then calls `exec`, which refuses unless the lease is `active`. The happy path
cannot complete. The fix is a generation counter rather than a sticky state —
`reap` increments it, `exec` records the generation it registered under and
refuses to drop on a stale one — but that is a design change made in a round
with no review left to confirm it.

Eight further Highs, all precise:

- The lease state field has no atomic mutation protocol.
- Bare pids cannot give safe retirement: pid reuse needs a pidfd or the start
  time from `/proc/<pid>/stat`.
- **"Container boot id" is wrong.** `boot_id` identifies the VM, which every
  container on the host shares, so it does not distinguish a container start at
  all. The epoch has to be written by the entrypoint.
- Gauntlet is not given the inputs the broker contract requires.
- The trusted-tooling scope names the Bun preload risk but not the actual seam.
- The privilege drop is not specified or attested as irreversible.
- `reconcile` before `down` races a live agent.
- Pre-spawn preflight failures have no durable classification path.
- The inherited-descriptor closure rule was lost in the rewrite.

Pattern across this mechanism: each round resolves most findings and introduces
one or two new consistency defects of my own. The round-7 critical, the
round-6 script-count drift and the stale `0027` reference are all that species,
not design faults. That is the limiting factor now, and it argues for a fresh
context rather than more iteration in this one.


---

## Relocation spec (2026-10-14) — two gates, eight rounds

Spec: `2026-10-14-agent-write-isolation-relocation-design.md`. Gate directories `run-GGDfJ0oZ` (rounds 1-4, ceiling) and `run-DxA6AYdK` (rounds 5-8, a continuation authorized by the human partner). Criticals: 0 throughout. Approves: feasibility at round 7, completeness at round 8. Finding counts by round: 11, 7, 6, 6, 5, 4, 2, 1.

### Adjudications

This spec supersedes `2026-10-13-agent-write-isolation-design.md`, which is
shelved. The threat model changed; that change is adjudicated and is the
premise of this review, not a finding to raise.

## Decisions

1. **Threat model: careless, not adversarial.** Taken 2026-10-14 after two
   measurements. (a) Across all 2,438 normalised trajectories in the run
   corpus, no Coding-Agent action referenced `verdict.json`,
   `trajectory.json` or the token-usage file; one run listed its parent
   directory and did nothing further. In ~1,624 of those runs the agent had
   been told, via the leaked repository `AGENTS.md`, that it was the graded
   subject and where the verdict lived. (b) A survey of the field (SWE-bench,
   Terminal-Bench, METR, Harbor, Inspect) found grading isolated by location,
   not privilege, and documented tampering only under pressure conditions this
   harness does not apply. Under the careless model the design removes
   adjacency and withholds credentials; it does not build a boundary.
   Declined: continuing the adversarial design (shelved, four mechanisms and
   seven gate rounds deep, nine open items).
2. **Move the workspace, keep the record where it is.** Declined, with costs
   stated to the human partner: moving the record (about twelve reader files,
   a new citation convention, and Gauntlet's pane scratch dragged into the
   record tree unless the fork changes first); no relocation at all (leaves
   the record in the agent's parent listing, the one interaction the corpus
   shows).
3. **No digest seal.** Declined because under this model nothing writes the
   record after composition, and same-uid storage gives detection nothing to
   stand on. A reviewer may raise a concrete post-composition writer if one
   exists; "an adversary could" is not one under decision 1.
4. **Verification:** offline tests plus three live smokes (Claude, Codex,
   Antigravity) and one paired control arm at n=10 per arm on the baseline
   cell nearest 50%. The limited power of n=10 is accepted and stated.
5. **One repository.** evals only; the Gauntlet fork is untouched.

## Facts established by inspection or measurement

- `runPhase` builds the checks environment from `envSnapshot()` — the entire
  quorum process environment — and `verbCommandSucceeds` spawns `bash -c`
  with no `env` argument, so post-check inner commands inherit provider keys
  and the record sink today.
- The only external variables shipped `checks.sh` files reference are
  `QUORUM_AGENT_CONFIG_DIR` (73 occurrences across 23 scenarios),
  `QUORUM_RUN_DIR` (4, all reaching `home/`) and `HOME` (3, all in comments).
- The check tooling reads `PATH`, `QUORUM_RECORD_SINK` and
  `QUORUM_TRANSCRIPT_PATH` from the environment.
- The Gauntlet launch environment is composed separately in `spawnGauntlet`.
- Antigravity rejects `--add-dir` paths with a hidden component.
- The dashboard scan skips any directory whose name does not parse as a run
  id.
- Zero evaluation runs have ever executed in the container: 2,442 generated
  launchers all name a host path, none names `/workspace/evals`.

### Round ledger

Spec: docs/hyperpowers/specs/2026-10-14-agent-write-isolation-relocation-design.md

## Round 1 (completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`. Eleven blocking findings across the two lenses, seven
distinct after merging overlaps. Each was read against the cited code before
acting. The spec was regenerated once rather than patched per finding.

### Resolved

- **`QUORUM_RUN_DIR` in the inner projection** (both lenses). Removed from the
  inner layer; outer-only, with the double-quote expansion rule for a scenario
  that genuinely needs a record path inside an inner command, and a new
  `quorum check` lint that fails a single-quoted `$QUORUM_RUN_DIR` in
  `command-succeeds`, mirroring the existing `$QUORUM_WORKDIR` rule.
- **Inner commands retained the operator's `HOME`/`TMPDIR`** (both lenses).
  The inner layer now overlays `HOME`, `XDG_*` and `TMPDIR` from
  `xdgHomeEnv(runHomeDir)` (`src/agents/home-env.ts:12-21`), the launcher's
  own single source of truth, so `npm test` runs under the agent's throwaway
  home. The outer (trusted) layer keeps the operator's `HOME`; the three
  `$HOME` occurrences in shipped checks are comments.
- **Kimi's artifact-root derivation** (both lenses). Confirmed at
  `src/agents/kimi.ts:191-198,829-850`: `dirname(dirname(workdir))` becomes
  `<outRoot>/workspaces`, so a `TMPDIR` inside `<outRoot>` but outside
  `workspaces/` would pass the guard. Fixed by threading the record directory
  through `RunHome.runDir` and taking the artifact root as its parent; test
  and counterexample added to the gate (offline item 4).
- **`strip-runs` liveness** (completeness). Confirmed: nested writes do not
  refresh the workspace mtime while the record directory is written at every
  phase boundary. New rule: strippable only when `verdict.json` exists and the
  newer of record-dir and verdict mtimes is older than the threshold; applies
  to both layouts; a test case pins the old-workspace/no-verdict skip.
- **Evidence step 2 (`.git` rename)** (completeness). All four archival steps
  now name the tree each path lives in; the gitlink check walks both trees.
- **Paired-control metric ambiguity** (both lenses). Observable fixed as
  criterion 1 (`criteria[0]` and `criteria[1]` of `result.json`), extracted by
  the re-baseline's `tally.py`; the composed final (1/10 on this cell) is
  explicitly not the observable; the two automatic stops have stated timing.
- **All-scenario post-phase replay was an assumption, not a gate item** (both
  lenses). Promoted to numbered offline item 6 with a concrete mechanism
  (`scripts/replay-post-checks`), eligibility (newest run with a verdict per
  scenario), comparison (recorded `checks` array by name and arguments) and a
  retained artifact.
- **TDD regression test omitted** (both). `test/scenario-tdd-project-suite.test.ts:203-213`
  confirmed to inject `QUORUM_RUN_DIR`; added to the change set, with
  `test/agent-kimi.test.ts` and the unchanged-by-design `test/checks.test.ts:277`.
- **Docs inventory** (both, medium). Enumerated as nine with the `rg` command
  that produced the list; the scenario-authoring env table gets the layer
  column and `QUORUM_AGENT_HOME`.
- **"Exactly the allowlist" not executable in bash** (both, medium/low).
  Exactness defined over the constructed env objects; the bash-level dumper
  ignores `PWD`, `OLDPWD`, `SHLVL`, `_` and asserts planted secrets absent.
- **Layout invariants overstated** (completeness, low). Pairing qualified to
  runs that reach workspace setup; the parent listing now includes
  scenario-created siblings.

### Declined — corrected, with evidence

- **"Inner commands retain credential-bearing homes" — the
  `QUORUM_AGENT_HOME` / `QUORUM_AGENT_CONFIG_DIR` half** (feasibility, high).
  The operator-`HOME` half of this finding is real and is resolved above. The
  agent-home half is declined as not a disclosure: those paths hold the
  subject's own tokens, which the subject held as the same uid for the entire
  agent phase; a post-check learning the path adds no capability the agent did
  not already have. Removing them would also require rewriting the 73 shipped
  `QUORUM_AGENT_CONFIG_DIR` bootstrap checks as typed verbs, recorded as a
  separate, reasonable piece of work. The spec states this reasoning in
  "Post-check environment".

### Still open

None.

## Round 2 (completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`; both confirmed every round-1 resolution is present and
the one decline's reasoning intact. Seven findings, four distinct.

### Resolved

- **Replay covered post only** (both). Offline item 7 now runs `pre` and
  `post` in both arms. 80 `command-succeeds` calls live in `pre()` across the
  scenario set, so the phase mattered.
- **Replay oracle could not reproduce the corpus** (both). The recorded
  verdict is dropped as the oracle — current checks have drifted from the
  newest runs and this design rewrites four more. Replaced by a counterfactual
  A/B: the *current* `checks.sh` runs twice on cloned artifacts, once under the
  legacy environment construction (reproduced in the script) and once under
  the new allowlist; ordered `(phase, check, args, negated, passed)` sequences
  must be identical. Eligibility is defined (a recorded post phase and a
  surviving workspace; 61 of 98 scenarios have a run), non-eligible scenarios
  are listed with a reason, and the pre-phase caveat is stated.
- **`RunHome.runDir` broke typed fixtures outside the inventory** (both).
  All construction sites enumerated — the runner literal, `makeTempHome`, and
  seven test files with direct literals found by a `configDir`+`workdir[,:]`
  search — and bound to one task so `tsc --noEmit` is green at every commit.
  The Kimi test description that implied "runDir = config dir's parent" is
  replaced by an explicit fixture with separate record and workspace trees
  under one temp out-root and an assertion that the secret stays outside the
  whole out-root.
- **Agent-owned `bunfig.toml` executes in the trusted outer layer**
  (completeness, out-of-lane). Measured rather than argued: on Bun 1.4.2 a
  plain `bun run <abs script>` from a workdir with a preload executed the
  preload and loaded the workdir `.env`; `--config=<trusted>` stops the
  preload, `--env-file=/dev/null` stops the `.env`, both together stop both;
  `--cwd` also works but would move the verbs' `process.cwd()`. All four
  prelude dispatchers gain the two flags, pointed at the repository's own
  `bunfig.toml`; the probe is kept as offline item 3.

### Declined

None this round.

### Still open

None.

## Round 3 (completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`; both confirmed every round-2 resolution present. Six
findings, five distinct; one shared. No criticals, no declines.

### Resolved

- **Replay did not isolate workspace siblings** (completeness). Confirmed on
  a recorded `worktree-no-drift-to-main` run: linked-worktree pointers are
  absolute in both directions. The clone now takes the whole workspace,
  runs `git worktree repair` (git 2.56.0 here), validates that every `.git`,
  `gitdir` and absolute symlink resolves inside the clone, rewrites intra-run
  absolute symlinks, lists external ones, and hashes the source before and
  after. That run becomes the script's isolation regression test.
- **No seam for two environments through `runPhase`** (both). `runPhase` is
  split into `runPhaseWithEnv(args, env)` — the single executor, which also
  owns sink creation — and the production wrapper over `outerEnv`. The
  replay calls the primitive twice. No duplicate executor.
- **`RunHome` inventory included unrelated types** (completeness). Confirmed:
  the `agent-codex-app-server` literals are `ReadHookArgs`; every other
  `provision()` call in `test/` passes a `makeTempHome` home. Inventory
  corrected to the three typed construction sites, with `tsc --noEmit` as
  the completeness check.
- **Relocation disabled Copilot's secret-leak scan** (feasibility). Confirmed
  at `src/runner/index.ts:727` / `src/agents/copilot.ts:445-475`; it is the
  only content walk rooted at a run directory in `src/`. The cascade gains
  `workspaceDir`, scans both roots, and its test gains counterfactuals under
  the relocated workdir and home.
- **Arm L lacked `QUORUM_AGENT_HOME`** (feasibility). Correct and a plain
  error in the replay definition: the four migrated checks would have failed
  in the legacy arm for a reason unrelated to hygiene. Arm L now carries that
  one contract variable; the spec enumerates the exact per-arm difference and
  adds a migrated-scenario replay as a script test.

### Declined

None.

### Still open

None.

## Round 4 — ceiling reached (backstop)

Both `needs-attention`; both confirmed every round-3 resolution present. Eight
findings, six distinct. `gate-round` ceiling 4 is spent: no further Codex
invocation for this gate directory. Every finding was verified before this
entry was written; none re-opens an adjudicated decision.

### Confirmed, disposition pending the human partner

1. **Replay inner-command seam** (both). `runPhaseWithEnv` varies only the
   outer env; `verbCommandSucceeds` builds the inner projection
   unconditionally, so both arms get the new inner behaviour. Needs an explicit
   mode the dispatcher reads and withholds from the nested command, exit-code
   comparison, and a mutation test. The proposed TDD sentinel is vacuous:
   every recorded `.test-history.log` is in the old text format while the
   current check expects JSON, so it fails in both arms — the fixture must be
   synthetic.
2. **Control-arm analyzer** (completeness). `tally.py:180` globs
   `home/.claude/projects/*/*.jsonl` under the run path; relocated runs keep
   transcripts under `workspaces/<run>/home`. Needs a campaign analyzer taking
   record and workspace roots, tested on one fixture per layout.
3. **Git content filters** (both). **Measured:** `git status --porcelain` with
   both hygiene flags invoked a repository-configured clean filter on a
   same-size change and on a stat-dirty unmodified file, and the filter
   received `HOME=/Users/johnss51` and the record sink. Harness git spawns
   must run under the inner projection as well as the flags; the probe becomes
   the test.
4. **Clone-pointer rule contradiction** (completeness). The worktree fixture
   carries an external absolute symlink
   (`home/Applications/Claude Code URL Handler.app/Contents/MacOS/claude` →
   `~/.local/share/claude/versions/2.1.287`). Git pointers and intra-source
   symlinks must resolve inside the arm; external references are classified
   and permitted; the assertion is "no pointer reaches the source or the
   opposite arm".
5. **Bun source-time invocation** (feasibility). `prelude.sh:20` runs
   `list-check-verbs.ts` through a fifth `bun run`, unflagged, with its stdout
   fed to `eval`. Needs the same two flags; the regression test must fail on
   merely sourcing the prelude.
6. **Codex wrong-cwd detector** (feasibility). Confirmed at
   `src/capture/index.ts:396`: containment is tested against `runDir`, so
   after relocation it never fires. Threads `workspaceDir` as the containment
   root with a relocated-layout counterfactual. A sweep of every `runDir`
   comparison in `src/` finds exactly Kimi, Copilot and this site: the
   relocation-breaks-a-derivation class is fully enumerated.

### Declined

None.

### Note

Finding counts by round: 11, 7, 6, 6 distinct. Criticals: 0 throughout. The
derivation class (Kimi, Copilot, wrong-cwd) is closed by sweep; the hygiene
class produced two measured trusted-layer defects (Bun preload/.env, git
filters) that only review surfaced.

### Round 4 fixes — applied with the human partner's authorization for one continuation gate

1. Inner seam: `QUORUM_INNER_ENV=projected|legacy` carried in the outer env,
   read by the dispatcher, never passed to the nested command; also governs
   the git spawns. Replay compares exit codes too; script tests gain a
   planted-dumper seam test, a synthetic TDD fixture in the current JSON
   format, and the Arm-L-without-`QUORUM_AGENT_HOME` mutation.
2. Analyzer: a campaign copy of `tally.py` taking `--records`/`--workspaces`,
   unit-tested on one fixture per layout.
3. Git: spawns run under the inner projection plus the flags; the measured
   clean-filter probe is offline item 4.
4. Pointer rule: three classes (git pointers, intra-source symlinks, external
   references); invariant "no pointer resolves into the source or the opposite
   arm".
5. Bun: all five `bun run` invocations in `prelude.sh`, including the
   source-time `list-check-verbs.ts` call; the dispatcher test now covers
   sourcing alone.
6. Detector: `DetectMisplacedCodexRolloutsArgs.runDir` → `workspaceDir`;
   counterfactual test; the derivation-class sweep recorded in the spec.

## Round 5 — continuation gate, round 1 (completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`; both confirmed the six round-4 fixes present. Seven
findings, five distinct; no criticals; no declines.

### Resolved

- **Detector repair was directionally wrong** (both). Confirmed: the pane's
  scratch cwd is in the record tree, so a launcher-skipping Codex lands outside
  `workspaceDir`. The detector now tests containment against both roots; three
  counterfactuals (record-tree scratch, wrong workspace subdir, launch cwd).
- **Pre-phase `agentHome` wiring** (both). `RunPhaseArgs.agentHome` is
  required; both production calls (`:1159`, `:1524`) pass `runHomeDir`; the
  fifteen inline constructions in `test/checks.test.ts` are the only test
  sites; the allowlist test now runs through `pre` and `post`.
- **`makeTempHome` record dir must exist** (completeness). Confirmed via
  `kimi.ts:838` `realpathSync`; the helper creates it and asserts it.
- **`cli-run-sigint.test.ts:263`** (completeness). Confirmed; it enumerates by
  `parseRunDirName`. A sweep of every `readdirSync` over an out-root found
  exactly this one affected site; `strip-runs` now excludes `workspaces` by
  name; `resolve-target` is safe because it filters on `verdict.json`.
- **Novel-failure stop undefined** (feasibility). Defined as a normalized
  signature `(final, error.stage|none, sorted failed check names)` computed
  from `verdict.json`; analyzer compares per-arm sets; fixtures for both
  outcomes.
- **Provisioning failures leave both trees** (completeness, low). Corrected:
  workspace creation precedes `agent.provision()`; only exclusion or an early
  guard leaves a record alone.

### Declined

None.

### Still open

None.

## Round 6 — continuation gate, round 2 (completeness-and-consistency, feasibility-and-scope)

Both `needs-attention`; both confirmed the round-5 fixes present. Four
distinct findings; no criticals; no declines.

### Resolved

- **Replay accepts identical vacuous failures** (feasibility). Confirmed on
  the cited run: `installed_plugins.json` names a stub under a cache that
  `strip-runs` deleted, and the current pre-check executes it. Added an
  anti-vacuity prerequisite — checks the recorded verdict passed, with
  unchanged text, must pass in Arm L — demoting failures to "non-replayable:
  degraded archive"; coverage is reported against eligibility; migrated
  scenarios with degraded archives get synthetic fixtures. Regular-file
  absolute paths are declared not rewritten, with the consequence stated.
- **`git worktree repair` without arguments can rewrite the source**
  (completeness). Correct per the man page and the copied pointer shape; the
  spec now requires every cloned linked worktree as an argument, a pre-check
  that the copied pointers name out-of-arm paths, and a disposable fixture
  for the test rather than the retained corpus run.
- **`QUORUM_INNER_ENV` contradiction** (completeness). Legacy is now the
  dispatcher environment minus the selector; projected strips it too; absence
  asserted in both modes in the dumper and git-filter tests.
- **Live gate underspecified** (completeness). Smokes named:
  `00-quorum-smoke-hello-world` on `claude-auto`, `codex`, `antigravity`.
  Paired control predeclared: `claude-auto`, `claude-opus-5-5`, Gauntlet-Agent
  `claude-opus-5-5`, same plugin root, CLI version recorded and required equal
  across arms. The analyzer parameterizes `--plugin-root`, `--model`,
  `--cc-version` and recognises both layouts for own-run containment.

### Declined

None.

### Still open

None.

## Round 7 — continuation gate, round 3

Feasibility: **approve** (normalized `approved`, 0 blocking) — the first
approve across both gates. Completeness: `needs-attention`, two Highs, both
confirmed, no declines.

### Resolved

- **Anti-vacuity contradicted pre-on-post-state** (completeness). A logic
  error in round 6's fix: `pre()` replays against the post-agent state, so a
  historically passing `git-clean` must fail once the agent created a file.
  The prerequisite is now phase-correct (post-phase records only); pre
  divergences from history are listed and classified once as state-dependent
  or degraded, with a synthetic counterfactual per degraded command shape. A
  predeclared coverage floor was added: at least two-thirds of eligible
  scenarios replayable, every inner-command tool (12 named) exercised, and
  all four migrated scenarios covered.
- **Manipulation-check failures had no disposition** (completeness).
  Confirmed in `tally.py:353-363,380-403`, which silently excludes them. Now
  an automatic stop in either arm; exactly ten qualifying sessions per arm
  required; replacements only under the project's existing void rule
  (`docs/scenario-authoring.md:863-868`, cap three per arm for grader-exit
  voids); analyzer fails closed below ten; fixtures for both cases.

### Declined

None.

### Still open

None. Round 8 is the continuation gate's final round.

## Round 8 — continuation gate, round 4: ceiling reached

Completeness: **approve** (normalized `approved`, 0 blocking). Feasibility:
`needs-attention`, one High, first raised in this round. `gate-round` ceiling
4 is spent: no further Codex invocation for this gate directory.

### Confirmed, disposition pending the human partner

- **Replay equality cannot hold for two migrated scenarios as written**
  (feasibility). `codex-approach-gate-fires-on-architecture/checks.sh:20` and
  `codex-plan-gate-algorithm-locked-after-round1/checks.sh:23` use outer
  double quotes, so the outer shell expands the home path before dispatch and
  the dispatcher records the expanded command in `args`; Arm L and Arm N have
  different clone roots, so their raw records differ even when both pass.
  The other two migrated checks and the synthetic TDD fixture are
  single-quoted, which is why the gap was not exposed. Fix shape: migrate the
  two checks to the single-quoted form (expansion in the nested shell), and
  canonicalize each arm's clone root to a placeholder in `args` before
  comparison so any other outer-expanded absolute path is tolerated; add a
  replay regression using one of these exact command shapes.

### Declined

None.

### Totals across both gates

Rounds: 8 (4 + 4). Criticals: 0. Approves: feasibility r7, completeness r8.
One finding declined with evidence (round 1, agent-home paths). Every other
finding confirmed against code or by measurement and resolved.

### Round 8 disposition — human partner: "fix and defer to the plan gate"

Fixed in the spec: the two double-quoted migrations become single-quoted
(exactly two such sites exist; the other six outer-double-quoted inner commands
are `awk` over relative paths); the replay canonicalizes arm roots to `<ARM>`
in `args` before comparing and reports rewrites (expected zero); a synthetic
fixture in the exact migrated shape asserts byte-identical records in the
single-quoted form and divergence in the old form. **Unreviewed by Codex**;
the plan gate is the confirming review. Recorded in the spec itself under
Verification item 7.

## Relocation plan (2026-10-14) — plan gate, four rounds

The implementation plan `docs/hyperpowers/plans/2026-10-14-agent-write-isolation-relocation.md`
was gated against the relocation spec (hp `bab5914`) before execution. The round
ledger below is copied verbatim from the gate's working directory, with its headings
demoted one level; the raw lens outputs it cites (`round1/` … `round4/`) stayed in
that scratch directory and are not committed.

Outcome: the plan executed with subagent-driven development on hyperpowers-evals
branch `agent-write-isolation-relocation` (16 tasks, 2026-10-14 to 2026-10-19) and
was merged into evals `main` at `882844154`. The paired control's predeclared rule
decided `proceed threshold (p_b=4 p_n=6)`. The evidence note is
`evidence/2026-10-14-agent-write-isolation-relocation/README.md` in hyperpowers-evals.

### Round 1 (coverage-and-consistency, feasibility-and-ordering)

Both `needs-attention`: 14 and 13 blocking findings, nineteen distinct after
merging overlaps. Each was read against the cited evals code at `b6a923a31`
before acting. Raw outputs: `round1/`.

#### Resolved

- **`tee` masks exit statuses** (coverage, critical; feasibility). Tasks 11,
  14 and 15 run their pipelines under `set -o pipefail` and record
  `${PIPESTATUS[0]}` beside the log; Task 15's launcher records each row's
  exit status beside its log.
- **Task 2's projected tests could not pass** (both). `ctxFor(cwd, env)` takes
  an explicit map (`test/check-tool.test.ts:35-48`), so the tests now pass
  `{QUORUM_INNER_ENV, QUORUM_AGENT_HOME}` through `ctxFor` and plant the base
  with `withEnv`; `innerEnv` allowlists its own base (`OUTER_PASSTHROUGH`,
  `LC_*`, `QUORUM_*`) so a planted provider key never reaches the inner map.
- **Missing offline witnesses** (both). Task 1 gained outer-bash exact-dump
  tests for pre and post (ignoring `PWD`, `OLDPWD`, `SHLVL`, `_`); Task 2 a
  `core.fsmonitor` marker test and two `runPhase`-level inner tests; Task 4 a
  production-path witness `test/cli-run-layout.test.ts` through `runCli` under
  the mock Gauntlet (`test/cli-run.test.ts:20-70`), and `buildRunHome` so the
  runner's `RunHome` literal is built by the function the tests exercise.
- **Task 9's eligibility API** (coverage). `eligibleRuns(resultsRoot,
  scenariosRoot, knownAgents)`; demotion reasons in a declared order
  (`setup-stage-verdict`, `no-post-records`, `stripped-workspace`, `no-run`);
  the test's expectations match that order; fixtures come from a schema-valid
  `verdictFixture()` factory (`schema`, `final`, `final_reason`, `gauntlet`,
  `checks[].detail/phase`, `error`, `economics`); imports trimmed to what each
  file uses.
- **Source and cross-arm isolation not enforced** (both). `replayRun` hashes
  the source record and workspace before cloning, after each clone and after
  both arms run, asserting equality each time, and walks each arm's pointers
  asserting none resolves into the source or the other arm; a corpus
  integration test over `worktree-no-drift-to-main-claude-auto-20261003T112456Z-f670`
  (skip-with-reason when absent) pins it.
- **Anti-vacuity accepted an absent record** (both; feasibility critical). An
  unchanged historical post check with no current Arm L record is
  `degraded-archive`; a fabricated corpus run whose `post()` does `exit 127`
  between two checks is the regression. Note: `runPhase` runs the phase
  without `set -e` (`src/checks/index.ts:94`), so a command-not-found would
  not abort; the fixture uses an explicit `exit 127` (crash band, `:136`).
- **Synthetics inflated the floor** (both; feasibility critical). `coverage()`
  counts only results with `runId !== null` toward `replayable`; synthetics
  still count toward tool and migrated-scenario coverage; the unit test has a
  synthetic and a corpus result and asserts `replayable === 1`.
- **Task 10 did not implement the deferred Authority item** (both).
  `ArmResult { raw, canonical, rewrites, exitCodes, home, root }`;
  `compareArms` compares canonical; the double-quoted regression asserts raw
  inequality, rewrites > 0 and canonical equality; the single-quoted form
  asserts byte-identical raw records and zero rewrites.
- **Task 10 imports and async signatures** (both). `agentConfigDir` and
  `loadAgentConfig` from `src/contracts/agent-config.ts:50-67`; `replayRun`
  and `replayFixture` return Promises and every test awaits them; timeouts
  per the repo convention (`60_000`; `300_000` for the corpus test).
- **Analyzer stops** (both; feasibility critical). `decide` adds the
  grader-exit void cap (three per arm, `void-cap`), the new-arm immediate
  stops (`indeterminate` + `error.stage == 'setup'`, or
  `qa-agent-misconfigured`), computes signatures over `verdict.final != 'pass'`,
  and tests all six manipulation checks in both layouts (twelve cases).
- **Criterion fixture shape** (coverage). `result.json` fixtures carry three
  `criteria` entries with `verdict` fields, the shape `criterion_one` reads.
- **Paired arms did not share a results root** (both). One absolute
  `CAMPAIGN_ROOT` passed as `--out-root` to every launch in both arms and to
  the analyzer; `git worktree add .worktrees/baseline-b6a923a31 b6a923a31`
  from the evals checkout.
- **Task 12's inventory** (coverage). `README.md:203` (actor table) added;
  `docs/manual-testing.md` gets the one clarifying sentence rather than being
  left out of the nine.
- **Task 11 mis-tiered** (both). Now high; allowlist edits removed from its
  scope — a divergence that needs a new variable stops for the human partner
  and, if approved, becomes its own high task appended to the plan.
- **Artifact directories not created** (coverage). `mkdir -p` precedes every
  live run in Tasks 11, 14 and 15.
- **Legacy strip-runs fixture stays recent** (feasibility). The fixture's
  `touch -t 202001010000` now covers `verdict.json` too.
- **Commits without the full gate** (feasibility). Global Constraint:
  `bun run check` before every commit, named in each task's final step.
- **Task 4 sweep expectation** (coverage, medium). The recorded output now
  includes the `kimi.ts:196` comment match.

#### Declined — with evidence

- **"[out-of-lane] The plan commits without the required human diff
  approval"** (feasibility, high; evidence `AGENTS.md:7-14`). The cited file
  is the hyperpowers repository's (`CLAUDE.md:13`, reached through its
  `AGENTS.md`), where the gate runs. Every commit this plan prescribes lands
  in hyperpowers-evals, whose `AGENTS.md -> CLAUDE.md` carries no such rule
  (grep for "approv", "complete diff", "before committing": no match). The
  human partner's standing instruction executes plans through SDD, which
  commits per task on a feature branch in an isolated worktree; their
  approval point is Finish, where the whole branch is reviewed before any
  merge. The Global Constraints now say exactly this; a per-commit stop would
  contradict the standing instruction.

#### Algorithm Assessment — adjudicated and locked

- **Algorithm locked:** ordered canonical comparison with separate raw
  records (was canonicalize-in-place). Both lenses suggested it; adopted.
- **Algorithm locked:** anti-vacuity by expected-set membership — an expected
  historical post check with no current record demotes (was found-and-failed).
  Both lenses suggested it; adopted.
- **Algorithm locked:** two-thirds floor over corpus runs only; synthetics
  count toward tool and scenario coverage, never the numerator. Adopted.
- **Algorithm locked:** failure signature `(final, error.stage|none, sorted
  failed checks)` over verdict-level non-passes, with the setup and
  `qa-agent-misconfigured` stops as independent, unconditional rules. Adopted.

### Round 2 (coverage-and-consistency, feasibility-and-ordering)

Both `needs-attention`: 10 and 7 blocking findings, fifteen distinct after
merging the five both lenses raised. Three were round-1 repairs that did not
hold (`compareArms`, the Task 14 status capture, the Task 4 sweep); the rest
were new or exposed by the round-1 changes. Raw outputs: `round2/`.

#### Resolved

- **The corpus replay pointed at the worktree's empty `results/`**
  (feasibility, critical). `results/` is gitignored (`evals/.gitignore:1`).
  Task 10's corpus test resolves `CORPUS_ROOT` through `git rev-parse
  --git-common-dir` (or `QUORUM_CORPUS_ROOT`), skips only when no corpus root
  exists at all, fails when the root lacks the named run, and the task's
  acceptance requires zero skips on this host; Task 11 derives the same root
  in bash, asserts the named run is under it, and passes it as `--results`;
  `scripts/replay-post-checks` exits 2 on an empty root (adjudication 7).
- **`compareArms` read `.records`** (both). Compares `canonical`; the unit
  test now constructs two arms whose raw args differ only by arm root and
  asserts canonical equality, plus a named divergence when a canonical
  record differs.
- **Anti-vacuity lacked the spec's "current text unchanged" condition**
  (coverage). `expectedPostChecks(text, roots)` builds the expected set by a
  static scan of the current `post()` body (shell-words tokenizer; `not` and
  `check-transcript` prefixes; the four `QUORUM_*` expansions; `<ARM>`
  canonicalization), independent of either arm's records; unmatched history
  is listed and never demotes; unparsable lines are listed. A second
  fabricated run (`moved`) pins that a changed check stays replayable
  (adjudication 8). The lock's wording stands: an expected check with no
  current record demotes.
- **Pre/post environment contracts disagreed** (coverage). Production passes
  `runDir` to both phases and `transcriptPath` only to post; Task 1 states
  that this is the contract, its dump tests now use the two production
  argument shapes and assert `QUORUM_TRANSCRIPT_PATH` only in post, Task 10's
  `runArm` takes `{pre, post}` args and builds each phase's env separately,
  and Task 12's table row says "pre and post" (adjudication 6).
- **Projected git verbs returned `false`/`''` on a missing agent home**
  (coverage). Every git verb (`:300,311,326,349,352,377,380,394,398`) starts
  with the `nestedEnv` check and returns `broken`; `gitOk`/`gitOut` take the
  resolved env; a regression asserts `git-clean` and `git-branch detached`
  are broken, not passing, under projected mode without a home.
- **fsmonitor witness contaminated by fixture setup** (coverage).
  `gitRepoWith` configures after the commit; the test asserts the marker is
  absent before invoking the verb.
- **Snippets that cannot pass the gate** (both). Task 2's spurious import
  note removed (`verbGitClean` is already imported); Task 4 imports
  `buildRunHome` and calls `runCli('pass')` with the exact copy ranges and
  the fixture names; Task 5 extends the `src/agents/index.ts` import with
  `type RunHome`; Task 6 adds `basename` to the `node:path` import.
- **Task 9's clone contract contradicted the external-reference rule**
  (coverage). The interface now states the three pointer classes: git
  pointers and rewritten intra-source links resolve inside the arm (throw
  otherwise); external references stay and are listed; nothing resolves into
  the source.
- **Task 11 could validate an uncommitted scenario repair** (both). Task 11
  never edits `scenarios/`; an operator-home-dependent check stops the task
  and becomes its own standard-tier task with a regression, gate, review and
  commit before the `--only` re-run.
- **Task 14 lost the producer statuses** (both). `${PIPESTATUS[0]}` is
  captured on the line after each pipeline into the smoke's log; acceptance
  names the permitted `run exit` values (0 pass, 1 fail; 2 indeterminate is a
  failed smoke — `src/cli/trials.ts:35-40`) and requires `show exit` 0.
- **The analyzer could not separate the arms** (feasibility). `--baseline-logs`
  and `--new-logs` are separate directories using the re-baseline's file
  naming so `LOG_NAME` (`tally.py:40`) and `collect()`'s glob (`:314`) apply
  unchanged; `collect` runs once per directory; Task 15's launcher writes
  `control/logs/<arm>/control-<scenario>-p<n>.log`; tests for the collector
  and for arm separation added.
- **Task 4's sweep inventory** (both). The expected output is the ten actual
  lines at `b6a923a31`, each classified.
- **Eligibility tests omitted `no-post-records`** (coverage, medium). A test
  with a newest-no-post/older-eligible pair and an all-no-post scenario.
- **Grounding line for runner error handling** (coverage, medium). Cites the
  throw, the catch (`:907-917`) and `errorStage` (`:950-963`).

#### Declined

- none this round.

#### Locks

- Unchanged. The anti-vacuity lock's expected set is now constructed from
  the current scenario text, which is what "expected" meant in the spec; the
  rule "expected with no current record demotes" is as locked.

### Round 3 (coverage-and-consistency, feasibility-and-ordering)

Both `needs-attention`: 6 and 6 blocking, ten distinct (two shared). Three
were round-2 repairs that did not survive contact with the real scenarios and
toolchain: the static scanner, the `noProcessEnv` claim, the Task 14 capture.
Raw outputs: `round3/`.

#### Resolved

- **The scanner excluded a quoted `$(`** (both, critical). The tokenizer is
  quote-aware; quoted text is opaque; only unquoted or double-quoted
  expansion, unquoted control operators, an unexpandable variable or a bash
  keyword makes a line unparsable; an unparsable line whose verb matches an
  unmatched historical pass makes the run `degraded-archive`. New unit test
  over `worktree-no-drift-to-main/checks.sh:10-14` verbatim plus a
  double-quoted `$(` and a `for` line; the corpus test asserts `equal`, no
  unparsed lines, no unmatched history, and that aborting just before the
  `command-succeeds 'test "$(git …)"'` line degrades the run (adjudication 9).
- **`bun run check` could not pass** (both). The plan's claim that tests are
  exempt from `noProcessEnv` was wrong: the override is an exact list. Tasks 1,
  4 and 10 add their files to it and stage `biome.json`; every `process.env`
  access is bracketed; Task 3 reads through `getEnv`; the `innerMode` fixture
  is a typed `Record<string, string>` lookup. Global Constraint added.
- **Offline replay depended on live credentials** (feasibility). The replay
  parses the agent YAML through `AgentConfigSchema` (`offlineAgentConfig`);
  `loadAgentConfig` is named as the thing not to call (adjudication 13).
- **`PIPESTATUS` under zsh** (feasibility). Tasks 11, 14 and 16 run committed
  bash scripts (`run-replay.sh`, `run-smoke.sh`, `tally.sh`, and Task 15's
  `launch-all.sh`), each anchored on its own location; Global Constraint
  added (adjudication 10).
- **Task 16 wrote outside its evidence directory** (feasibility). Every
  `control/…` path is `$EVIDENCE_DIR/control/…`; the scripts anchor on
  `dirname "$0"`.
- **Task 7 mis-tiered** (feasibility). High (adjudication 12).
- **`collect` could not receive its inputs** (coverage). `Config` dataclass
  threaded through `run_dir`, `readouts`, `own_roots`,
  `manipulation_failures` and `collect(logs, cfg)`; `main()` builds it once;
  test 8 points `cfg` at each fixture tree.
- **Void kinds inconsistent** (coverage). One `classify(verdict, result)`
  with the renamed kinds and the exact verdict shapes (`error.stage`,
  `gauntlet.status`/`summary`, `criterion_one`); six fixture verdicts; a
  `classify` CLI subcommand; `decide` stops on new-arm `void-harness-setup`
  or `qa-agent-misconfigured` by kind (adjudication 11).
- **The launcher was unspecified** (coverage). New high-tier Task 15 with the
  complete sequential alternating launcher (bash 3.2 — the host's only
  bash — no associative arrays), a fake `quorum run` that copies the fixture
  verdicts, and seven asserted cases (order, exit retention, log names,
  replacement, cap, setup relaunch, new-arm stops, no-run-id). The old Task
  15 is Task 16 and consumes it.
- **Archive procedure covered one layout** (coverage). Steps 2–3 branch on
  layout; Task 16 applies the legacy branch to the baseline arm.
- **README record block** (feasibility, medium). Both `coding-agent-workdir/`
  and `home/` removed, with a mechanical check.
- **`makeTempHome` invariants** (feasibility, medium). The helper asserts the
  record directory exists and is not a workspace path; a regression in
  `test/runner-layout.test.ts`.
- **mypy on both Python files** (feasibility, medium). Done.
- **Docs inventory without `results/<`** (coverage, medium). The spec's full
  query is run; remaining `results/<` lines are classified mechanically
  (no `home`, `coding-agent-workdir` or `.claude` under `results/<run>/`).

#### Declined

- none this round.

#### Locks

- Unchanged.

### Round 4 (coverage-and-consistency, feasibility-and-ordering) — the ceiling

Both `needs-attention`: 4 and 3 blocking, six distinct (the `getEnv` import
shared). Both lenses state that spec coverage, Grounding and Mirror
citations, interfaces, risk tiers and the locked algorithms hold, and that
Tasks 7 and 10 correctly implement the deferred Authority item. Every
residual is a snippet-level execution defect. Raw outputs: `round4/`.

#### Resolved in the plan after the ceiling (unreviewed by Codex)

- **Dotted access on `Record<string, string>` values** (coverage). Bracket
  notation at every site (18 `expect(env.X)`/`expect(inner.X)`, 10 `out.X`,
  `env['KIMI_ENV_FILE']`, `base['PATH']`).
- **`getEnv` not imported in Task 3's test** (both). Imported.
- **`makeTempHome` regression** (coverage). `makeTempHome` returns
  `{ home, cleanup }`; the regression now passes `workdir` and `runDir` in
  one invocation, checks the happy path, and cleans up; the helper removes
  its temp root before refusing.
- **Launcher output could poison the campaign logs** (coverage). `OUT_DIR`
  (default beside the script); the test uses a temp `OUT_DIR` and asserts
  nothing lands under `control/`; Task 16 requires an empty `logs/` and no
  `manifest.tsv` before launch and passes `OUT_DIR="$EVIDENCE_DIR/control"`.
- **Continuation folding** (feasibility). `expectedPostChecks` folds
  unquoted backslash-newline continuations before tokenizing; the unit test
  carries `codex-gate-backstop-finding-forces-choice/checks.sh:31-33`
  verbatim and expects the five-argument `tool-arg-match` key the corpus
  recorded (`…-f903/verdict.json:81-92`).
- **Result glob for void runs** (feasibility). The launcher resolves
  `result.json` first and omits the optional argument when absent; the test
  asserts each void row's kind.

#### Disposition

The document-gate ceiling (4) is reached. These six fixes were applied
after the last Codex round and are therefore Codex-unreviewed; the next
instrument that checks them is `bun run check` at every commit and the
per-task Codex code gate during SDD. The human partner decides whether to
proceed on that basis or to spend a further round in a new gate directory.

#### Locks

- Unchanged.
