## 3. Invoke Codex by artifact type

Use absolute paths for every file placeholder. Prefer file handoffs over pasted
content; the prompt should point Codex at the source material, not copy it.

Write the gate's own scratch files — the prompt files named in gate-lenses.md and the recipe files, the round ledger,
and any handoff — inside a fresh per-run scratch dir. At gate start, run the
helper once and capture its output as `GATE_DIR`:

```bash
GATE_DIR="$(bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/codex-review-dir")"
```

(In a hyperpowers dev checkout `$CLAUDE_PLUGIN_ROOT` is unset; the `:-.` fallback
runs `skills/requesting-code-review/scripts/codex-review-dir` from the repo root.)
The helper prints a unique directory under
`${XDG_CACHE_HOME:-$HOME/.cache}/hyperpowers/codex-review/`, created for this one
gate invocation. **Use one `GATE_DIR` for the whole gate** — every prompt file
and the round ledger live inside it, and every round reuses the same dir. Because
the dir is unique per invocation, two review gates running at once — even two
Claude Code sessions in the same worktree, or the spec gate and code gate of one
run — never share a ledger or clobber each other's prompt files. Never hand-write
these files under `.git/`, `~/.claude/`, or anywhere outside the working
directory: those paths are protected or out-of-workspace and force an approval
prompt on every write, which is why the helper places them under the user cache.
The reviewed artifact (spec, plan, diff) stays where it lives — only the gate's
transient scratch goes in `GATE_DIR`.

On a re-review (round 2+), prepend the round-aware preamble from §5 (Round
ledger) to the recipe prompt for this gate type and pass the ledger path, so Codex confirms prior
resolutions instead of re-reviewing cold. The first round composes the per-lens prompts from the lens fan-out block in gate-lenses.md instead of this single prompt.

Run `task` in the **foreground** — as written in recipe-document.md, with no `--background`. The
default `task` mode blocks and returns Codex's result inline when the review
finishes; there is nothing to poll for and nothing to wait on. Never add
`--background` to a document review: it enqueues a detached worker and forces you
into a `status`/`result` polling loop for no benefit. Do not `sleep` and then
poll — the foreground call already returns exactly when Codex is done. Give the
blocking call an explicit command timeout of **600000 ms (10 minutes)**:
document reviews typically finish in 2–5 minutes, but default tool timeouts are
far shorter and an aborted call loses the verdict.

**Count every round — the first included.** Before composing ANY LOGICAL round (round 1 included), run §5 step-0's `gate-round` counter once for this `GATE_DIR`; a round-1 lens batch counts as ONE round — individual lens launches within the batch do NOT advance the counter; only a `"verdict":"proceed"` may launch the batch (or the single re-review).

**Assemble the dossier — reviewers receive, rather than fetch.** Only a
`"verdict":"proceed"` from the logical round's `gate-round` call reaches
this step: on `backstop` or a non-zero exit, stop before assembling
anything (a stopped round leaves no `dossier.md`, keeping the
dossier-presence telemetry signal clean). On proceed, build the gate's
context artifact:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-.}/skills/requesting-code-review/scripts/review-dossier" --gate <spec|plan|task|final|adhoc> --out "$GATE_DIR" <inputs per the table below>
```

| Gate | Inputs to pass |
|------|----------------|
| spec | `--spec <spec path>` plus `--adjudications <path>` for any approved-design/decision context |
| plan | `--doc <plan path> --doc <spec path>` plus `--adjudications <spec-gate round ledger path>` |
| task/adhoc | `--adjudications <spec decision excerpts / spec-gate ledger> --test-evidence <implementer report path> --base <task BASE> --head <head sha>` |
| final | all of the above: plan/spec docs, ledgers, Minor ledger, branch `--base <merge-base> --head <head>` |

The dossier renders every expected-but-missing input as `NOT PROVIDED`
(reviewers treat that axis as cannot-verify) and gate-type-inapplicable
inputs as `NOT APPLICABLE`. If the dossier build itself fails, the gate
falls back to the path-based prompts with the failure named in the §6 hand-back — never blocked,
always attributed. **The fallback keeps the SAME approval contract:**
compose the same lens prompts with the dossier line replaced by the
original path-based context lines (the artifact/brief/report paths the
recipes name), so every fallback lens still carries the lens charter, the
exhaustiveness demand, and the required `Coverage:` section — its axes
answered from what the reviewer fetched — and round-1 fallback captures
are normalized with `verdict-normalize --require-coverage` exactly like
dossier-backed ones. One approval rule everywhere; the only thing a
fallback loses is delivered context.

