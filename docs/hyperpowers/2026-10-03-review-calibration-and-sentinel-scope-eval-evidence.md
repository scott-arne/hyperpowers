# Review Calibration and Sentinel Scope — Eval Evidence

Date: 2026-10-03 (runs 2026-10-04 local time)
Skills changed: none. Fix 1 stopped at RED; Fixes 2 and 3 are documentation
(hyperpowers `CLAUDE.md`, evals `docs/scenario-authoring.md` §5).
Scenarios: none. Fix 1 used direct Codex reviews of fixture diffs (evals
repo); Fixes 2 and 3 had no live runs.

Spec: `docs/hyperpowers/specs/2026-10-03-review-calibration-and-sentinel-scope-design.md`.
Plan: `docs/hyperpowers/plans/2026-10-03-review-calibration-and-sentinel-scope.md`,
pre-registered in `c7f4063`.

**Where the run artifacts live.** Every `task-4-runs/` path in this note
resolves under the evals repository's committed evidence tree,
`evals/evidence/2026-10-03-review-calibration-and-sentinel-scope/`
(hyperpowers-evals commit `403435c69`). The runner wrote there
directly; nothing in this note cites the SDD workspace.

## Fix 1 — the pathological-input cap (stopped at RED)

**Defect.** The third-pass Codex gate on the external-workflow-adoption
branch blocked on defects that only hand-made input reached: invalid UTF-8
bytes in a path, a plan directory name containing a newline, `printf %q` on
invalid UTF-8 under bash 3.2, dot-prefixed workspaces a glob skipped, and a
C0 byte in a ledger path. The 2026-09-05 calibration (Arm A of
`docs/hyperpowers/2026-09-05-gate-calibration-eval-evidence.md`) scoped
severity to what a diff causes, but nothing in it says how to rate input no
caller produces.

**Sentence.** Proposed for the three focus strings in
`skills/requesting-code-review/recipe-code.md`, after "Naming, style, and
speculative hardening are low.": "A defect reachable only through input that
nothing in the code or its callers produces and that only the person running
it could supply — a newline or invalid UTF-8 in a file or directory name, a
name that starts with a dot — is medium, unless it also breaks the default
path or corrupts stored data." It did not ship.

**Method.** Direct Codex reviews of fixture diffs, three per fixture per arm,
through evals `scripts/codex-focus-arm.sh` at `fd1b5c701`. Each review's
prompt is the correctness-lens skeleton of a round-1 task gate followed by
the arm's focus file. The control file is `recipe-code.md` line 53 at
`5bef46c` with its path placeholders pointed at the fixture; the runner
proves that, and that the treatment file is the control file plus the
sentence, before any review. As in Arm A, the fixture's `review.diff` stands
in the dossier slot. RED came first: control had to block the pathological
fixture in at least 2 of 3 reviews before the treatment ran. If P blocked in
at most 1 of 3, P2 ran; if P2 did too, the plan stopped.

**Fixtures** (evals `fixtures/codex-focus-arm/`):
- P: `formatWorkspaces` writes each workspace directory name plus a newline;
  `countWorkspaces` counts that report's non-empty lines, so a name with a
  newline counts twice.
- P2, committed before any review: `formatWorkspaces` prints the first seven
  characters of the name's twelve-hex-digit match and throws on any other
  name.
- Pc: `markAll` appends a `<name>\t<kind>` line per workspace to
  `events.log`, so a name with a newline splits a stored record. Not run.
- M, H and O, from 2026-09-05: a clean diff, an ordinary-input crash, an
  omitted requirement. Not run.

The library creates only twelve-hex-digit names, and P's and P2's
requirements say so.

**Reviewer.** gpt-5.6-sol at xhigh, codex-cli 0.160.0, companion 1.0.6,
normalized by `verdict-normalize` blob `7111b3b5` (the one at `5bef46c`).
Both runtime records of both invocations are byte-identical to
`task-4-runs/control-P/runtime-start.txt`.

**Decision rule** (pre-registered): the treatment wins if P blocks in at most
1 of 3, Pc in at least 2 of 3, H in 3 of 3 and O in 3 of 3, and M is approved
in at least 2 of 3. It was never applied: the treatment did not run.

**Results.**
- P control 1: approved (`task-4-runs/control-P/P-control-1.json`)
- P control 2: approved (`task-4-runs/control-P/P-control-2.json`)
- P control 3: approved (`task-4-runs/control-P/P-control-3.json`)
- P2 control 1: approved (`task-4-runs/control-P2/P2-control-1.json`)
- P2 control 2: approved (`task-4-runs/control-P2/P2-control-2.json`)
- P2 control 3: approved (`task-4-runs/control-P2/P2-control-3.json`)

Treatment did not run. All six verdicts are `approve` with no findings; no
review reported the defect at any severity. P2 control 2's summary says the
functions produce the required results "under the stated workspace-name
invariant". `tally.txt` reproduces from the captures. No voids, no re-runs.

**Decision.** Stop: no over-rating reproduced on P or P2 under control, so
no sentence ships. `recipe-code.md` and `test-gate-contract.sh` are
unchanged, and Tasks 5 and 6 did not run.

What the stop does not show: the production gate saw a full dossier with no
statement about which inputs callers produce, while both fixtures' requirements
state the twelve-hex-digit invariant. Whether that sentence kept the reviews
from raising the case is untested. A successor fixture would drop it.

## Fix 2 and Fix 3 — scoped sentinel re-measurement and harness-labeled base rates

No live runs; both are documentation.

- **Evals.** `docs/scenario-authoring.md` §5 rewritten in evals `8f8b6c526`:
  a re-measure is owed only for a change a sentinel session reaches, and every
  base-rate row carries a harness label with a row-selection procedure. Four
  rounds of the per-task Codex gate found defects in the plan's mandated text;
  the human partner ruled on each, and evals `93777fbbf`, `81b24c0b1`,
  `9a53cb272` and `ed220c9cc` carry the fixes. The plan and spec record them
  as appended corrections (`cc1af48`, `cb67114`, `cd67425`, `760e455`). The
  gate converged at round 5 of 5.
- **Hyperpowers.** `CLAUDE.md` gains the sentinel pointer in `8dd6b79`
  (Task 2, low tier; tier-skip recorded).
- **Hermeticity record.** `evals/evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`
  (in `8f8b6c526`), the record behind §5's `clean` row: `bun test
  test/agent-claude.test.ts test/runner-context.test.ts` at `be020f0d0`, 39
  pass, 0 fail, `# Result: exit 0`.
- **Task 1 Step 5 checks.** At `8f8b6c526` and after fix rounds 1 to 3:
  `bun run check` 1295 pass, 0 fail unsandboxed, and `bun run quorum check`
  exit 0. After fix round 4, `bun run check` ran under load average 28 to 44
  and hit 5000 ms timeouts in tests that pass alone and do not read the doc;
  the full green run (1295 pass, 0 fail) came at Task 3's `fd1b5c701`.

## Deviations

From the plan, recorded before execution:

1. The runner's broker is keyed to a fresh `mktemp -d` directory, not the
   evals checkout, so an arm never reviews through or stops a broker it did
   not start.
2. The spec's comparability path set is not the one
   `logs/measure-launch.sh:31` pins (all of `scenarios`); §5 says the
   launcher's set narrowed to the scenario's own directory.
3. §5's rows 1 and 2 cite the live ids `62d8044`, `d6a1681` and `7aff2a7` in
   place of the ids the 2026-10-01 history rewrite replaced, with a
   translation note.
4. P2 is pre-registered: committed before any review, so it could not be
   tuned to P's result.
5. The evals doc says "the maintainer", matching the evals `CLAUDE.md`.
6. Runtime records: six lines (the spec lists four), six or more records that
   must all agree, and an end record on every exit after the start record.
7. Files beyond the spec's list: `tests/codex-review-gate/gate-post-split-edits.tsv`
   (Task 6, not run), evals `scripts/codex-focus-arm.test.sh`,
   `fixtures/codex-focus-arm/P2/`,
   `evidence/2026-10-03-harness-confound-attribution/hermeticity-be020f0d0.txt`,
   and the evidence directory's `cap-sentence.txt`, `tally.py`, `tally.txt`
   and `README.md`.

From execution:

- Task 1's text departs from the plan's Step 2 in four places, each recorded
  as an appended correction after the human partner's ruling (above).
- The one sandboxed launch the plan allows went to a scratch directory, not
  `task-4-runs/`. It failed on the sandbox before any review and is not part
  of the evidence.
- Inside the Bash sandbox the proxy variables the plan's leak grep reads hold
  the sandbox proxy's values, so every staged diff was also scanned for the
  host's values by a counts-only scanner. Both scans found nothing.
- The plan's Grounding describes the attribution experiment entry's labels
  as Question, Pre-registration, Config, Results, Limits and Files; that
  entry uses Hypothesis, Config, Run pointers, Verdict and Limits. This
  plan's entry follows the plan's labels.
- Global Constraints lists `task-5-runs/` in the evidence directory; on the
  Stop path it does not exist.
- Task 7's offline suites were not all green on the first run, and the
  branch changes no code. Fresh pipes on the host held 512 bytes while 128
  Codex brokers, 245 app-servers and 122 code-mode hosts were running, so
  seven shell suites failed through SIGPIPE in `printf | grep -q` under
  `pipefail` and through truncated Node output. After `codex-broker-sweep
  --kill --include-unreferenced` retired 92 orphan brokers, pipes held 65536
  bytes and all seven passed. The brainstorm `server.test.js` still fails 7
  of 33 checks, each one waiting on a file-change reload: the host's FSEvents
  delivered one write's event after 3.1 s and another's not at all, against
  the test's 500 ms waits. `stop-server.test.sh` and
  `windows-lifecycle.test.sh` pass only outside the Bash sandbox, which
  blocks `ps`.
