# Upstream Issues for openai/codex-plugin-cc — Ready to File

File at: <https://github.com/openai/codex-plugin-cc/issues/new>

Five independent issues. Each section below is self-contained: copy the
**Title** into the issue title field and everything under **Body** into the
description. They are ordered by observed impact; they can be filed in any
order and none depends on another. Observations come from a Claude Code
plugin integration that drove codex-plugin-cc 1.0.5/1.0.6 through several
hundred review jobs over roughly two months on macOS.

After filing, record the issue URLs in
`docs/hyperpowers/plans/2026-07-22-gate-reliability-hardening.md` (Task 10
section) to close acceptance criterion 7.

---

## Issue 1

**Title:** Broker fails terminally on stale socket after macOS temp dir purge

**Body:**

**Problem**

The broker state file (`~/.claude/plugins/data/<plugin>/state/<repo-key>/broker.json`)
records a Unix socket path under a macOS per-user temp directory (typically
`/var/folders/...`). macOS purges these directories (commonly overnight),
removing the socket while leaving `broker.json` intact. Every subsequent
companion call then fails with `connect ENOENT <socket-path>` until a new
session re-provisions the broker.

**Observed**

In a Claude Code plugin integration running hundreds of review jobs over two
months, this failure pattern grew from single digits to roughly 240 transcript
occurrences per month as usage scaled. The socket and session directory are
gone but the broker record remains, so all requests fail until manual
intervention or a fresh session triggers re-provisioning.

**Proposal**

On `connect ENOENT`, validate the recorded `sessionDir` and `pid` (directory
existence and process liveness). If either is invalid, treat the broker record
as stale and re-provision automatically rather than failing terminally. This
would let the companion self-heal from temp-directory purges without caller
intervention.

---

## Issue 2

**Title:** Review jobs can exit success with null result when verdict is truncated

**Body:**

**Problem**

Review jobs can terminate without writing a parseable terminal verdict,
leaving the stored job result with `result: null` and exit code 0. This occurs
when the review session ends (truncation, timeout, or internal stop) while the
model is still formatting its verdict output.

**Observed**

In a sample of 273 document-review sessions, 10 ended with no terminal
verdict. One ran approximately 20 minutes and stopped mid-sentence while
formatting the verdict. The stored job shows `result: null` with exit 0, which
callers cannot distinguish from a clean run without inspecting session logs.

**Proposal**

Explicitly mark such jobs `incomplete` (or `truncated`) instead of leaving a
null-result success shape, so callers can detect and handle unfinished reviews
without parsing logs.

---

## Issue 3

**Title:** No per-request way to launch reviewer sessions without harness skill bootstraps

**Body:**

**Problem**

Stateless one-shot reviewer sessions launched via `task`/review commands load
the same harness skill-bootstrap context as interactive sessions. An ephemeral
reviewer never uses that context, but pays for it on every launch — and on
every round of a multi-round review.

**Observed**

In a sample of 273 reviewer sessions, 53% spent their first tool calls
re-reading harness bootstrap content (32% as the literal first action) —
overhead with no benefit to a one-shot reviewer.

**Proposal**

Add a documented per-request flag (e.g. `--skip-bootstrap`, or a request
property) on the launch commands that starts the child session without
harness bootstrap context. A per-request mechanism matters because a
caller-side environment variable cannot express this safely: the persistent
per-repo broker captures its provisioning environment and replays it for
later, unrelated sessions, so an env marker set by one review would also
suppress bootstraps for subsequent sessions that want them.

---

## Issue 4

**Title:** Session cleanup intermittently logs EPERM on broker.json unlink

**Body:**

**Problem**

The companion's session-end cleanup intermittently fails to unlink
`broker.json`, logging `EPERM ... unlink broker.json` and leaving the stale
broker record on disk. This feeds the stale-socket failure mode (see the
temp-dir-purge issue): the next session finds a broker record pointing at
infrastructure that no longer exists.

**Observed**

`EPERM` failures during `broker.json` cleanup appear intermittently in session
logs under regular plugin usage. The record remains on disk and requires
manual removal, or a fresh session, before the repo's companion calls work
again.

**Proposal**

Diagnose the permission/ordering issue behind the `EPERM`. Make the unlink
best-effort with a retry, surface a warning instead of failing silently, and
ensure a failed cleanup cannot leave the broker record in a state that blocks
the next provisioning.

---

## Issue 5

**Title:** merge-base failure with invalid --base leaves review job stuck as "running"

**Body:**

**Problem**

When a review job's `--base` resolves to an invalid ref (for example the git
empty-tree hash `4b825dc642cb6eb9a060e54bf8d69288fbee4904`), the worker's
`merge-base` call fatals mid-job without writing a terminal state. The job
stays `running` forever, and every subsequent `status --wait` burns its full
timeout against a job that can never finish.

**Observed**

One review job was observed permanently orphaned this way: `--base` resolved
to the empty-tree hash, `git merge-base` fataled inside the worker, no
terminal state was written, and the result could never be retrieved.

**Proposal**

Validate the `--base` ref before starting the worker (e.g.
`git rev-parse --verify` plus a merge-base check against `HEAD`), recording
the job as `failed` with a clear error on validation failure. More generally,
ensure any fatal git error during job execution writes a terminal `failed`
state rather than leaving the job as `running`.
