# Agent Write Isolation — Design

**Date:** 2026-10-13 (mechanism revised 2026-10-14; container-scoped; rewritten
2026-10-14 after six gate rounds)
**Status:** design, paused with open items — see Open items
**Scope:** `hyperpowers-evals` (quorum) container runs, the `scott-arne/gauntlet`
fork, and this repository's plan and spec documents.

## Supersession

Three mechanisms preceded this one.

1. **Sandbox at Gauntlet's `--target`.** Rejected: `--target` is not the launch
   boundary.
2. **Confine the private tmux server** with Seatbelt and Landlock. Survived
   three rounds, each finding a new escape: the enforcement chain left `bun` and
   `tmux` writable; `file-write*` does not cover hard links; publishing an
   attestation was not a barrier; `tmux -S` takes any socket path so broker
   enumeration could never be complete; Landlock mediates no metadata rights;
   and quorum itself runs post-check commands against agent-written files with
   the record sink in their environment. Criticals ran 2, 1, 3, 3 with no decay.
3. **Privilege separation on host and container.** Sound, but the host half
   needs an administrator-created account and a sudoers entry, and `johnss51`
   is not in the `admin` group.

This revision is privilege separation scoped to the container, where every
obstacle is ours to remove because we build the image. Host runs are out of
scope and unchanged. The document was then rewritten once, after six review
rounds, because patch-on-patch editing had begun generating its own
contradictions faster than it fixed them.

## Problem

Quorum composes a run's verdict from artifacts in the same directory tree the
Coding-Agent writes to, and both run as the same OS user. `../verdict.json` is a
writable relative path from the agent's cwd.

The first sub-project added read-side rules — a verdict is trusted only once its
writer's process has exited, keyed on a pid and hostname in `phase.json` — and
recorded that an agent able to rewrite `phase.json` defeats them.

Two artifacts matter most: quorum's own record (`verdict.json`, `phase.json`,
`trajectory.json`, the token usage file), and
`<runDir>/gauntlet-agent/results/<runId>/result.json`, the Gauntlet-Agent's
grade. Quorum **discards Gauntlet's exit code** and takes the status from that
file (`src/runner/index.ts:201-230,336,353-354`), and the agent's shell starts
in a sibling directory of it.

## Decisions taken with the human partner

1. **Threat model: adversarial capability.** The agent will write anything
   reachable if that looks like success.
2. **Mechanism: privilege separation**, after four gate rounds against tmux
   confinement.
3. **Scope: container only.** Host runs keep today's behaviour and are
   documented as unprotected.
4. **Failure is fatal.** A container run that cannot establish the separation
   does not run. No opt-out.
5. **Verification:** a deterministic probe suite in the container, three live
   smokes (Claude, Codex, Antigravity), one paired control arm at n=10 per arm
   pinned to pre-change revisions.
6. **One plan across the three repositories.**

## The launch topology

1. Quorum spawns the `gauntlet` CLI (`src/runner/index.ts:323`).
2. **Gauntlet's TUI adapter ignores `--target`**: `async start(_target: string)`
   (`gauntlet/src/adapters/tui/adapter.ts:114-129`); only `describeTarget` reads
   it, as prompt prose (238-247).
3. `start()` creates a private tmux server running `bash --norc --noprofile -i`
   (121-130). The pane cwd is `<runDir>/gauntlet-agent/results/<runId>/scratch`,
   a sibling of `result.json`.
4. The **Gauntlet-Agent, an LLM, types a command into that pane**, instructed to
   type `"$QUORUM_LAUNCH_AGENT"` (`coding-agents/codex-context/HOWTO.md:6-24`).
5. That is a launcher quorum generates per run
   (`src/runner/index.ts:1241-1256`) from one of eight templates.

The launcher is therefore **advisory** — an LLM may ignore it, which is already
the detected `qa-agent-misconfigured` mode — so the boundary is the pane, not
the launcher.

## Design

### Identities

| Identity | Runs | Owns |
|---|---|---|
| **root** | one broker script, nothing else | — |
| **harness** (`quorum`) | quorum, Gauntlet, the tmux server, Gauntlet's tmux clients, the check verbs | the run directory and every record file |
| **agent** (one per run, from a pool) | the pane's shell and all descendants; post-check commands that execute agent-authored content | nothing in the record tree |

The container runs with no `--user`, and the image declares `USER quorum`, so
`docker run` and `docker exec` both land on the harness identity. The launcher's
synthetic `/etc/passwd` and `/etc/group` mounts
(`scripts/evals-container:403-418`) are removed, because they contain only
`root` and `evals` and would hide every account the image creates.

The image creates `quorum` with uid and gid from build arguments matching the
invoking host user, so bind-mounted files stay host-owned, and a pool of agent
accounts `quorum-agent-0..N` from uid 2000, each with its own primary group. The
harness is a member of every agent group; no agent is a member of any other
agent's group, of the harness group, or of any group granting a device or
socket.

Per-run identities close cross-run tampering, and they also make reaping
complete: every process owned by the account belongs to this run.

### The tmux server stays with the harness

Only the pane's shell drops. The adapter's session command becomes a broker
invocation, so the interactive shell, anything the Gauntlet-Agent types, the
launcher, the Coding-Agent and every descendant run as the agent identity.

Dropping the server itself is not workable: tmux 3.8 creates sockets with
permissions excluding every user but the owner and gates others behind
`server-access`, so a harness client could not drive an agent-owned server.
Keeping the server with the harness also means the agent **cannot reach the tmux
socket at all** — it is `0700`, harness-owned — so `run-shell` delegation is
closed by a filesystem permission rather than by an enumeration that `tmux -S`
could always defeat. Gauntlet's `capture-pane` and `kill-server` are unchanged,
and Antigravity teardown keeps searching the socket namespace it searches today.

### Ownership and permissions

| Path | Owner | Group | Mode |
|---|---|---|---|
| `<outRoot>`, `<runDir>` | harness | harness | `0755` |
| `verdict.json`, `phase.json`, `trajectory.json`, token usage, `provenance.json` | harness | harness | `0644` |
| `<runDir>/gauntlet-agent/` and its results tree | harness | harness | `0755` |
| the agent's launch cwd and `coding-agent-workdir-*` siblings | harness | this run's agent group | `2770` |
| `<runDir>/home` | harness | this run's agent group | `2770` |
| `<runDir>/gauntlet-agent/results/<runId>/scratch` | harness | this run's agent group | `2770` |

Unlink and rename of a record are closed because they depend on write permission
on the *directory*, and no directory holding a record is agent-writable.
Metadata mutation is closed because `chmod`, `chown` and `utimes` require
ownership. Both properties were measured; see Evidence.

### Handing over the populated tree

Mode bits on three root directories are not sufficient, because setup has
already populated them.

- **Recursive handover after setup and pre-checks**, covering the launch cwd,
  every setup-created `coding-agent-workdir-*` sibling including `.git`, and
  `<runDir>/home`. Scenario `setup.sh` also populates the home
  (`src/setup-step.ts:20-44`) and shipped stubs create nested directories the
  agent must later write
  (`scenarios/codex-gate-re-review-focus-is-fixed/setup.sh:164-191,235-257`), so
  `setup.sh` additionally runs with umask `0007`.
- **Generic rule:** group set to the run's agent group, directories `2770`,
  regular files `0660` preserving any execute bit.
- **Symlinks** are handled by an explicit `lstat` branch: the link is `lchown`ed,
  its target is never resolved, chowned or chmoded, and only the link's own path
  must be lexically inside the tree. Canonicalizing targets would abort every run
  that ships `.agents/skills/superpowers`, which points into the external
  Superpowers checkout by design (`src/setup-helpers/worktree.ts:91-102`). A
  non-symlink entry whose canonical path escapes the tree aborts the run.
- **Gauntlet prepares the scratch directory**, since it creates it inside
  `start()` after quorum's preflight.

**The credential manifest overrides the generic rule.** Provisioned credentials
keep the mode the manifest gives them — `0640`, or `0750` when executable — and a
family that refuses a group-readable credential gets that file placed
**agent-owned at `0600`** by the broker, which is the only component that can
chown to an agent account. Without this precedence the generic rule would
silently relax every credential to `0660`.

**External credential anchors are copied, not linked.** Several providers reach
outside the run home — AWS and ADC files in the real home, and token-cache
symlinks (`src/agents/index.ts:60-100,234-255,493-531`;
`src/agents/pi.ts:77-105,325-344`). A different uid cannot safely use those
through an `lchown`ed link, so provisioning copies the content into the run home
and rewrites the reference. The plan enumerates every family.

### The broker

**One root-owned script, `quorum-broker`, with verbs**, authorized by a single
`NOPASSWD` sudoers line naming the harness account as its only principal. One
script rather than several because a multi-script surface has repeatedly drifted
out of sync between its definition, its preflight, its sudoers rule and its
probes.

It cannot authorize by its own real uid: under `sudo` a command has root as both
real and effective uid. It requires root effective identity and compares sudo's
`SUDO_UID` against the configured harness uid.

Every verb except `reconcile` requires a matching, `active` lease, and validates
that each path argument is contained in that lease's run directory. All
traversal is descriptor-relative and no-follow (`openat` with `O_NOFOLLOW`,
`fchownat`/`fchmodat` with `AT_SYMLINK_NOFOLLOW`); symlink targets are never
modified; any traversal that would leave the leased tree fails closed. An
adversarial agent plants descendant symlinks precisely to catch a root-running
recursive `chown`.

| Verb | Contract |
|---|---|
| `exec --account --lease --cwd --policy launch\|postcheck --ready PATH --nonce N -- CMD` | registers its own pid in the lease as its first action, builds the environment for the named policy, clears supplementary groups, sets the primary group, sets umask `0007`, writes the readiness record, re-validates that the lease is still `active`, drops permanently, execs in place |
| `reap --account --lease` | terminates and waits for every broker pid registered in the lease, then `SIGTERM`/`SIGKILL` by account, then rescans until empty, bounded by a retry limit |
| `capture-own --run-dir --manifest` | takes ownership of the manifest's files in place, and makes their ancestor directories traversable by the harness |
| `reclaim --run-dir` | sets owner and group to the harness and strips group write throughout |
| `place-credential --account --lease --dest --mode` | writes stdin to an agent-owned file at the given mode; the only way an agent-owned `0600` credential can exist |
| `reconcile --out-root` | the one lease-less verb; see Reconciliation |

### Leases

Concurrent runs are separate `quorum run` processes
(`src/run-all/index.ts:157-184`), so "pick an unused account" is a race. Leases
live at `/var/lib/quorum/leases`, harness-owned `0700`, container-local because
they describe live processes in this container. Acquisition is an `O_EXCL`
create, which is atomic across processes.

A lease records the run directory, the owning quorum pid, a timestamp, the
**container boot id**, the registered broker pids, and a **state**: `active`,
`draining` or `released`.

The state field is the linearization point for the in-flight broker problem.
`quorum-broker exec` is root between registering and dropping, so a reap that
scanned only the agent uid could see an empty set while a paused broker was
about to drop into a just-released account. `reap` sets the lease to `draining`
first; `exec` re-validates immediately before dropping and refuses if the lease
is not `active`. A broker therefore either registers before draining starts and
is waited for, or fails to drop. Registrations are retired when the broker exits,
so a stale pid is never signalled later.

Release happens only after a successful reap and reclaim.

**Crash recovery** is conservative: a lease whose owner is gone is not simply
reusable. The account is reaped and proven empty, the lease's run directory is
reclaimed, and only then is the lease removed. Reaping alone would leave a
`2770` tree group-owned by that account for its next holder. An account that
cannot be proven empty is **quarantined** and never allocated again in this
container.

### Reconciliation

Run trees persist on the bind mount while leases do not, so a container that is
removed, or merely stopped and started, can strand an agent-owned tree with no
lease to authorize its recovery, and can leave leases naming pids that now
belong to unrelated processes.

`quorum-broker reconcile --out-root O` is the lease-less bootstrap. It reclaims
every subtree under the out-root owned or group-owned by a pool account, under
the same no-follow rules, serializes on a per-out-root lock, and writes a
completion marker under `/var/lib/quorum` **stamped with the container boot id**.

- Any lease or marker whose boot id differs from the current one is stale: leases
  are discarded without signalling their recorded pids, and markers do not count.
  This is what makes `evals-container up` on a stopped container safe, not only
  removal and recreation.
- Because `--out-root` is a runtime value, reconciliation runs **on demand**
  before the first lease for a given out-root in this container; preflight
  refuses until that out-root has a current marker. The entrypoint pre-runs it
  for the default out-root.
- `down` refuses to remove a container holding an `active` lease unless told to
  reconcile first.

### What else runs as the agent identity

The check verbs stay harness-side — `src/check/record.ts` is the sole record
emitter and `check-tool.ts` observes the exit status — but their inner commands
do not.

- `command-succeeds` runs its inner command through `exec --policy postcheck`.
- **Every `git` invocation against an agent-controlled repository** does too.
  Disabling hooks is not enough: `core.fsmonitor` names an executable `git
  status` runs, and other keys do the same, so the boundary is the identity
  rather than a list of config keys.
- `checks.sh` is scenario-authored and in-repo, so it keeps the harness identity
  and still reads sibling artifacts through `QUORUM_RUN_DIR`.

#### The trusted-tooling invariant

> A harness-identity process never runs with an agent-controlled working
> directory, and never loads configuration from an agent-controlled path.

Two known instances: post-check `bun` reads `bunfig.toml` from its cwd, so a
planted `preload` would run as the harness — trusted tooling therefore runs from
a harness-owned neutral cwd with automatic config and env loading disabled and
the workdir passed as an argument. OpenCode capture invokes `opencode export`
from the agent workdir against agent-writable config
(`src/agents/opencode-capture.ts:43-51,133-155`), so it runs through the broker.
The plan audits every post-agent subprocess against this invariant.

#### Two environment policies

- **`--policy launch`** builds the environment from a harness-owned, validated
  manifest naming exactly what an agent launch needs, including the corporate
  proxy settings a container agent requires to reach its provider.
  `sudo` resets the environment by default, which would otherwise strip them
  (`container/bin/quorum:18-23`; `src/runner/index.ts:317-329`) and fail runs
  before evaluation begins.
- **`--policy postcheck`** passes only `PATH`, `HOME`, `TMPDIR`, `LANG`,
  `QUORUM_RUN_DIR`, `QUORUM_WORKDIR` and `QUORUM_AGENT_CONFIG_DIR`. `runPhase`
  otherwise hands the inner command quorum's whole environment
  (`src/checks/index.ts:62-100`; `src/env.ts:12-15`), including provider keys and
  credentialed proxy settings that Copilot's launch path deliberately withholds.
  An allowlist fails safe as new variables appear.

`QUORUM_RECORD_SINK` is in neither. `QUORUM_RUN_DIR` is kept deliberately: two
shipped scenarios reference it inside single-quoted inner commands
(`scenarios/tdd-runs-the-project-suite/checks.sh:45-57`;
`scenarios/codex-gate-stale-broker-attributed/checks.sh:46-49`), and the record
is protected by ownership, not by the agent not knowing where it is.
`QUORUM_AGENT_CONFIG_DIR` is kept because post-checks resolve paths through it
(`scenarios/code-review-of-a-committed-change/checks.sh:40-47`). The plan
enumerates every `command-succeeds` use to confirm the list is complete.

### Phase order

1. The agent phase ends; `reap` proves the account empty.
2. **Brokered exports run** while the tree is still agent-owned. OpenCode export
   must read owner-only session state (`src/agents/opencode-capture.ts:182-197`).
   The account is reaped again afterwards.
3. `capture-own` takes ownership of the capture source files **in place** and
   makes their ancestors traversable. Nothing moves: Kimi's `sessionDir` values
   and Copilot's `expectedEventsLog` comparison key on live paths
   (`src/capture/cwd-filter.ts:77-154`; `src/runner/index.ts:699-755`), so a
   staging copy would make valid runs indeterminate. Owning files alone is also
   not enough — a CLI can create a `0600` transcript inside a `0700` directory it
   made, which the harness could not traverse — hence the ancestor fix.
   The manifest is per-agent: the `session_log_glob` plus declared auxiliaries
   such as Kimi's `session_index.jsonl`, which falls outside its `**/wire.jsonl`
   glob.
4. Capture runs exactly as today, against the original paths.
5. Post-checks run, inner commands brokered, with workspace and home still
   agent-accessible — which shipped post-checks inspecting the config dir and
   caches require.
6. `reap` a final time, then `reclaim`, which takes ownership and strips group
   write so no future holder of the account can reach this tree.
7. The lease is released.

**One owner for every exit.** The runner has many early returns and its existing
`finally` covers only the old runtime cleanup
(`src/runner/index.ts:1007-1020,1375-1427,1494-1519`). Lease ownership is a
single `finally`-style boundary wrapping everything after acquisition: on every
exit it reaps, reclaims and only then releases; if either cannot be proven, the
lease is retained and the account quarantined. SIGINT is in scope — the handler
today writes a stopped verdict and calls `process.exit(2)`
(`src/cli/index.ts:155-180`), bypassing every finalizer. It becomes an awaited
cancellation; a second signal forces exit and quarantines.

### Preflight

Before a run starts: the process is the harness identity and not root; `quorum`,
Gauntlet and tmux resolve to that identity; the broker exists and the sudoers
rule permits it and nothing else; this out-root has a current reconciliation
marker; an unquarantined account is available; a trivial `exec` reports the
expected uid, gid and empty supplementary set; and the three shared directories
have the expected owner, group and mode. Any failure is fatal.

### The ordering barrier

`adapter.start()` returns straight into `runAgent()`
(`gauntlet/src/runs/orchestrator.ts:195-215`), so the agent must not be driven
before quorum confirms the separation. All four records are files under
`<runDir>/gauntlet-agent/`, which the agent cannot write, each written to a temp
file and renamed. **Quorum generates the launch nonce**, passes it to Gauntlet on
the flag, and every record carries it; both readers validate it, and a record
whose nonce does not match is treated as absent.

| Record | Direction | Path | Fields |
|---|---|---|---|
| readiness | broker to Gauntlet | path given on the command line | `schemaVersion` `1`, `nonce`, `runDir`, `account`, `agentPid`, `uid`, `gid`, `supplementaryGids` |
| attestation | Gauntlet to quorum | `isolation.json` | the same, plus `mechanism: "privilege-separation"` |
| acknowledgement | quorum to Gauntlet | `isolation-ack.json` | `schemaVersion`, `nonce`, `runDir`, `decision`, `reason` |
| terminal failure | Gauntlet to quorum | `isolation-failure.json` | `schemaVersion`, `nonce`, `runDir`, `code`, `cause` |

The readiness path is an explicit argument because preflight invokes the same
broker and would otherwise write a record Gauntlet could mistake for the real
one; preflight passes a throwaway path.

`code` is closed: `separation-unavailable`, `separation-pool-exhausted`,
`separation-broker-missing`, `separation-broker-failed`,
`separation-identity-mismatch`, `separation-ack-timeout`,
`separation-ack-rejected`, `startup-config-invalid`,
`startup-provider-unavailable`, `startup-adapter-failed`, `startup-other`.

1. **Quorum, before spawning:** delete all four paths and verify each is gone.
2. **Gauntlet, inside `start()`:** assign the scratch directory, create the
   session with the broker as its command, wait for readiness, then **poll**
   `/proc/<agentPid>/status` until that pid reports the expected credentials or a
   timeout expires. A single read would race, because the broker publishes
   readiness while still root. Write `isolation.json` from what was observed,
   then **block** for the ack up to 60 seconds without returning.
3. **Quorum, while the child runs:** poll for the attestation or a terminal
   record up to 120 seconds; if both appear, failure wins. Validate the schema
   version, the nonce, that `runDir` matches, that `agentPid` is live and still
   reports the attested credentials, that `uid` is the allocated account and not
   the harness uid, that `gid` is that account's primary group, and that
   `supplementaryGids` is empty.
4. **On success:** persist `isolation.state = "enforced"`, update the in-memory
   snapshot the SIGINT handler holds, then write an accept ack.
5. **On failed validation:** write a reject ack and fail the run.
6. **Gauntlet on reject or timeout:** kill the session, reap, write the terminal
   record, exit **without driving the agent**.
7. **Quorum if its poll expires:** terminate Gauntlet, reap, fail.

Interruption is tested at every transition.

The terminal record is written by the earliest CLI boundary that knows the run
directory, not by the adapter, so a failure before adapter construction — a bad
config or an unavailable provider — still produces one.

### Classification and the record

| What quorum sees | Classification |
|---|---|
| valid attestation, accepted | run proceeds |
| terminal record, `separation-*` | setup `indeterminate`, naming the cause |
| terminal record, `startup-*` | the classification each produces today |
| no record, or unparseable | setup `indeterminate` — fail closed |
| the flag absent (standalone Gauntlet) | quorum always passes it; absence is `separation-broker-missing` |

| State | Meaning | Set when |
|---|---|---|
| `pending` | no decision reached; the agent was never driven | at start |
| `enforced` | attested and accepted; carries account, uid and gid | before the ack, therefore before the agent phase |
| `failed` | separation could not be established | on a `separation-*` record or failed validation |
| `not-applicable` | a host run | always, on the host |

`pending` covers every pre-enforcement termination, including an ordinary setup
failure. It never means an agent ran unprotected.

## Evidence already measured

Two probes were run in a Linux container during design, because the ownership
model is the whole mechanism. Both used `node:22-bookworm-slim`, a harness
account in the agent's group, and `setpriv --reuid --regid --clear-groups`.

**The denial set holds.** As the agent identity, all ten of these were refused
against a `0644` harness-owned `verdict.json` in a `0755` harness-owned run
directory: overwrite, truncate, unlink, rename-away, create a file at the run
directory, `mkdir` there, `chmod`, `utimes`, **hard link into the workspace**,
and symlink-then-write. The hard link and the metadata mutations are the two
classes Landlock could not mediate; here they fail on ordinary POSIX rules plus
`protected_hardlinks`. Writes inside the workspace and home succeeded several
levels deep.

**Umask `0027` was wrong**, which is why this design uses `0007`. The harness
could read an agent-created file once its real supplementary groups were present,
but `rm -rf` of an agent-created subtree failed with permission denied, because
`0027` yields `0750` directories whose group has no write bit.

Both are indicative, not the release gate: they ran in Debian while the eval
image is Ubuntu 26.04, and the probe suite re-establishes them there.

## Verification

### Deterministic probe suite

Container only, therefore Linux only. **Every denial probe carries a positive
control**: the same operation runs first as the harness identity and must
succeed, and the denial reason is asserted, because a probe passing on `ENOENT`
proves nothing. A probe whose positive control fails is inconclusive, not a pass.

Denials, as the agent identity:

1. Write, truncate, unlink, rename-out, rename-in and atomic-replace of
   `verdict.json`, `phase.json`, `trajectory.json` and the token usage file.
2. The same against `../result.json` from the pane's own cwd.
3. Creating any entry at `<runDir>`, and a forged
   `gauntlet-agent/results/<id>/result.json` under a new id.
4. Another concurrent run's workspace, home and record.
5. The generated launcher at `gauntlet-agent/context/launch-agent`.
6. Metadata: `chmod`, `chown`, `utimes`, xattr on a record file.
7. Hard link and symlink to a record file, then mutation through the link.
8. A writable descriptor opened before the drop, proving the broker's close rule.
9. `tmux -L <socket> run-shell` and `tmux -S <path>` against the harness-owned
   server, failing on socket permission.
10. `ptrace`, `process_vm_writev`, `pidfd_getfd` and a signal against the
    harness-identity quorum, Gauntlet and tmux processes.
11. Every broker verb, with valid and invalid arguments; an unauthorized command
    under `sudo`; a `SUDO_UID` spoof; and, as the harness, a path outside the
    out-root, an account outside the pool, and an account this run holds no lease
    on.

Allowances:

12. Create, write, rename and delete throughout the launch cwd, a
    `coding-agent-workdir-*` sibling, the home and the pane scratch, several
    levels deep.
13. A package-less `npm install` and a `git commit` as the agent identity.
14. Every credential family read by the agent identity, including the copied
    external anchors and any placed agent-owned `0600` file.
15. Harness cleanup of an agent-created subtree after `reclaim`.

Capture and post-checks:

16. Capture reads a transcript the agent created at `0600` **inside a `0700`
    directory the agent created**, proving both halves of `capture-own`.
17. A planted `bunfig.toml` preload, OpenCode plugin, `core.fsmonitor`,
    `.git/hooks/pre-commit` and plain executable, each attempting a record write
    when post-agent tooling runs. None may execute as the harness.
18. A planted environment dumper sees only the post-check allowlist; the launch
    policy contains every manifest variable including the proxy settings.

Lifecycle:

19. A double-forked and `setsid` descendant is still reaped by account; a process
    forking during the reap is caught by the rescan; an account that cannot be
    proven empty is quarantined.
20. Forced-interleaving allocation across two concurrent `quorum run` processes.
21. Sequential reuse: a second run allocated the same account after release
    cannot reach the first run's tree.
22. Killed-run recovery: a hard-killed run's account is reclaimed before release.
23. In-flight broker: `exec` paused between registration and drop, owner killed,
    recovery run — the account is not released while it lives, and the paused
    broker fails its pre-drop revalidation.
24. Container **stop/start** and **remove/recreate**: stale leases and markers
    from a previous boot id are discarded, reconciliation runs before the first
    lease, and the new run cannot reach the stranded tree.
25. Planted descendant symlinks to outside sentinels are not followed by
    `capture-own` or `reclaim`; the sentinels are unchanged.

Protocol:

26. The barrier case by case: readiness or attestation missing, malformed, stale,
    mismatched `runDir`, mismatched nonce in each of the four records, a late
    record, `uid` equal to the harness uid, non-empty supplementary groups, both
    records present, ack rejected, ack timed out, poll expired, each `startup-*`
    code, and a pre-adapter failure. Each asserts the agent was never driven and
    the account was reaped.

### Unit tests

Preflight; lease acquisition, state transitions, boot-id staleness and release;
the handover's generic rule, manifest precedence and symlink branch; attestation
validation including the harness-uid and supplementary-group rejections; broker
argument validation; and the reconciliation walk.

### Live verification

- **Three smokes** in the container on Claude, Codex and Antigravity, the
  families whose launch paths differ structurally
  (`src/agents/antigravity.ts:528-586`). Each must reach a verdict that is
  neither `qa-agent-misconfigured` nor a setup `indeterminate`, with capture
  showing normal workspace and home writes. A smoke failure stops the release.
- **One paired control arm**, n=10 per arm, both in the container:
  - **Unconfined arm:** checkouts pinned to evals `b6a923a31` and Gauntlet
    `a35607e`. Not produced by an opt-out, which decision 4 forbids.
  - **Separated arm:** the branch head, same scenario, agent configuration,
    credentials and host.
  - **Scenario:** one whose base rate is already recorded in the clean-harness
    re-baseline; the plan names it and cites the entry.
  - **Acceptance, predeclared.** With `p_s` and `p_u` the separated and
    unconfined pass counts and indeterminates never counted as passes:
    `p_u - p_s <= 2` with no automatic stop proceeds; a larger gap stops for a
    human decision. Automatic stops: any separated-arm run indeterminate for a
    `separation-*` reason; any permission error in a separated-arm transcript on
    a path the agent was supposed to be able to write; any new deterministic
    failure absent from the unconfined arm.
  - Arms interleaved so host load drifts across both equally.

Artifacts the evidence note cites go to
`evals/evidence/2026-10-13-agent-write-isolation/`.

## Files and repositories

**`scott-arne/gauntlet`** (branch from `main` at `a35607e`, `bun test`)
- `src/adapters/tui/adapter.ts` — prepare the scratch directory, run the session
  command through the broker, wait for readiness, poll `/proc` for credentials,
  publish the attestation, block for the ack, refuse to drive the agent without
  one. The tmux server itself is unchanged.
- A flag carrying the broker path, account, nonce and readiness path; the
  terminal record writer at the earliest CLI boundary that knows the run
  directory.
- `src/runtime/process-tree.ts` — reap by account rather than by ancestry.
- Adapter tests for accepted, rejected, timed-out and absent-flag paths.

**`hyperpowers-evals`**
- The identity module: pool allocation, the lease and its states, preflight, the
  handover, the broker wrapper, reconciliation, the lifecycle boundary.
- `src/runner/index.ts` — preflight, pass the flag, quorum's half of the barrier,
  terminal-record classification.
- `buildGauntletArgv` — the new flag and its argv test.
- `src/check/fs-verbs.ts` — route `command-succeeds` inner commands and all
  agent-repository `git` invocations through the broker under the post-check
  policy.
- `src/capture/` including `cwd-filter.ts`, and the Kimi and Copilot capture
  paths — in scope because `capture-own` changes who owns the sources and their
  path contracts are what ruled out a staging copy.
- Provisioning (`src/agents/*.ts`, `private-file.ts`, `kimi.ts`, `pi.ts`) — the
  credential manifest, agent-owned placements, copied external anchors.
- `src/cli/index.ts` — SIGINT becomes an awaited cancellation.
- Provenance — the `isolation` block and its four states.
- `container/Dockerfile` — both account sets from build arguments, `sudo`, the
  broker, the sudoers line, the entrypoint reconciliation, `USER quorum`.
- `scripts/evals-container` — remove `--user` and the passwd/group mounts, pass
  the build arguments, make `down` refuse an active lease.
- The probe suite.

**`hyperpowers`** — this spec and the implementation plan, tracked here by this
repository's standing exception.

## Constraints

- No change to any absolute path the Coding-Agent observes or records.
- No new runtime dependency in evals; `sudo` is an image package.
- Suites run on `/bin/bash` 3.2.57 on a heavily loaded host, so no short
  per-test timeouts.
- There is no CI; suites are run by hand, one script per `bash` invocation.

## Out of scope

- **Host runs.** They keep today's behaviour, where the agent can write the
  record, and the verdict says `not-applicable`.
- A compromised quorum or Gauntlet. The guarantee is against the Coding-Agent.
- Tamper-evidence against writers other than the Coding-Agent. The first
  sub-project's Known limits close **for the Coding-Agent in a container run**
  and remain open otherwise.
- The Gauntlet-Agent's conduct, including ignoring the launcher.
- What the agent writes outside the record tree; `/tmp` stays writable.

## Known limits

- **Only container runs carry the guarantee**, and any claim that a result was
  produced under write isolation must check `isolation.state`.
- The pool is finite: concurrency above it queues or fails preflight with
  `separation-pool-exhausted` rather than silently sharing an identity. The plan
  sizes it against the scheduler's global slot cap.
- A quarantined account is lost until the container is recreated. Quorum reports
  the remaining pool size so this is visible.
- A run killed between the reap and the reclaim leaves an agent-owned subtree
  until the next reconciliation, which the plan documents.

## Open items

Seven spec-gate rounds ran against this mechanism family. The direction was
confirmed viable by independent review in three separate rounds, and the
mechanism, ownership model, broker shape and verification plan below are
settled. These nine items were open when work paused on 2026-10-14, each with
reviewer evidence in the gate ledger beside this document. They are the first
thing to resolve when this resumes.

1. **The lease state machine blocks the phase order.** `reap` at phase step 1
   sets the lease `draining`, after which the brokered export at step 2 cannot
   `exec`. The intended fix is a **generation counter** rather than a sticky
   state: `reap` increments it, `exec` records the generation it registered
   under, and a stale generation refuses to drop. That change is unreviewed.
2. **The lease state field has no atomic mutation protocol.**
3. **Bare pids are unsafe for retirement.** Pid reuse needs a pidfd, or the
   start time from `/proc/<pid>/stat`, to confirm a registered pid is still the
   process that registered.
4. **"Container boot id" is wrong.** `boot_id` identifies the host VM, which
   every container shares, so it does not distinguish a container start. The
   restart epoch must be generated by the entrypoint and stored where a stop
   and start cannot preserve it.
5. **Gauntlet's launch handoff lacks required inputs** for the broker contract
   as written.
6. **The trusted-tooling invariant names the Bun preload risk but not the
   seam** that actually loads it.
7. **The privilege drop is not specified or attested as irreversible** — the
   `setresuid` semantics and `no_new_privs` are implied rather than required.
8. **`reconcile` before `down` races a live agent.**
9. **Pre-spawn preflight failures have no durable classification path**, and the
   inherited-descriptor closure rule was lost when this document was rewritten.

## Assumptions

**Assumption:** `sudo` honours a `NOPASSWD` rule naming the harness account under
the container's default seccomp, and `SUDO_UID` is present and trustworthy. The
design does **not** depend on `sudo` exec-ing in place: the readiness record names
the broker's own pid, and the broker execs in place.
*Validate by:* a probe in the built image running every verb, confirming an
unauthorized command is refused, confirming an agent identity is refused every
verb, and checking `/proc/<pid>/status` for the execed shell — before the first
broker task.

**Assumption:** removing `--user` and the synthetic passwd/group mounts, and
running with `USER quorum`, leaves bind-mounted files host-owned and every auth
mount readable.
*Validate by:* grepping the image and scripts for the `evals` account name, then
a container smoke that reads each credential family and writes a run directory —
before the first live container run.

**Assumption:** every agent CLI tolerates its credentials under the manifest's
modes, including families not covered by the three smokes, and can refresh
rotating OAuth credentials from an agent-owned file.
*Validate by:* a read-and-refresh probe per credential family before the paired
control arm. A family that fails gets an agent-owned `0600` placement, which the
broker's `place-credential` verb exists to provide.
