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
