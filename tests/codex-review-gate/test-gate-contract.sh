#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GATE="$REPO_ROOT/skills/requesting-code-review/codex-review-gate.md"
BRAINSTORMING="$REPO_ROOT/skills/brainstorming/SKILL.md"
WRITING_PLANS="$REPO_ROOT/skills/writing-plans/SKILL.md"
SDD="$REPO_ROOT/skills/subagent-driven-development/SKILL.md"
REQUESTING_REVIEW="$REPO_ROOT/skills/requesting-code-review/SKILL.md"
APPROACH_GATE="$REPO_ROOT/skills/brainstorming/codex-approach-gate.md"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"
  local haystack

  haystack="$(tr '\n\t' '  ' <"$file" | sed 's/  */ /g')"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$description"
  else
    fail "$description"
    echo "    expected to find: $needle"
    echo "    in: $file"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local description="$3"
  local haystack

  haystack="$(tr '\n\t' '  ' <"$file" | sed 's/  */ /g')"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    fail "$description"
    echo "    did not expect to find: $needle"
    echo "    in: $file"
  else
    pass "$description"
  fi
}

echo "Codex review gate contract tests"

assert_contains "$GATE" "## 3. Invoke Codex by artifact type" \
  "shared gate has artifact-specific invocation recipes"
assert_contains "$GATE" "**Spec documents**" \
  "shared gate has a spec document recipe"
assert_contains "$GATE" "**Plan documents**" \
  "shared gate has a plan document recipe"
assert_contains "$GATE" "<SPEC_ABSOLUTE_PATH>" \
  "plan recipe requires the source spec path"
assert_contains "$GATE" "<PLAN_ABSOLUTE_PATH>" \
  "plan recipe requires the plan path"
assert_contains "$GATE" "**Per-task code**" \
  "shared gate has a per-task code recipe"
assert_contains "$GATE" "<TASK_BRIEF_PATH>" \
  "per-task recipe requires task brief context"
assert_contains "$GATE" "<IMPLEMENTER_REPORT_PATH>" \
  "per-task recipe requires implementer report context"
assert_contains "$GATE" "<REVIEW_PACKAGE_PATH>" \
  "per-task recipe requires review package context"
assert_contains "$GATE" "<GLOBAL_CONSTRAINTS_PATH>" \
  "per-task recipe requires global constraints context"
assert_contains "$GATE" "**Final whole-branch code**" \
  "shared gate has a final whole-branch recipe"
assert_contains "$GATE" "<BRANCH_REVIEW_PACKAGE_PATH>" \
  "final recipe requires the branch review package"

assert_contains "$GATE" "### Required document-review output" \
  "document review output is explicitly structured"
assert_contains "$GATE" "Copy the Required document-review output block below into the prompt" \
  "document review prompts include the output schema in Codex context"
assert_contains "$GATE" "Cannot verify" \
  "document review output includes cannot-verify items"
assert_contains "$GATE" "line references" \
  "document review output asks for evidence"

assert_contains "$GATE" "After any code fix, re-run the same Claude reviewer gate before re-running Codex." \
  "code fix loop requires Claude re-review before Codex re-review"

# --- Task 1: convergence loop + per-gate backstops + round ledger ---
assert_contains "$GATE" "### Round ledger (re-review memory)" \
  "gate defines a round ledger for re-review memory"
assert_contains "$GATE" "every capture required for the latest round" \
  "approval set covers fan-out and re-review alike"
assert_contains "$GATE" "Document gates get 4 rounds" \
  "gate sets the document-gate backstop to 4 rounds"
assert_contains "$GATE" "Code gates get 3 rounds" \
  "gate sets the code-gate backstop to 3 rounds"
assert_not_contains "$GATE" "## 5. Fix-and-re-review loop (cap = 2 rounds)" \
  "gate no longer uses the single 2-round cap heading"

assert_contains "$SDD" "After any Codex-triggered code fix, re-run the task reviewer before re-running the per-task Codex gate." \
  "SDD per-task loop names Claude re-review order"
assert_contains "$SDD" "After any Codex-triggered final-review fix, re-run the final code-reviewer before re-running the final Codex gate." \
  "SDD final loop names Claude re-review order"
assert_contains "$REQUESTING_REVIEW" "After any Codex-triggered code fix, re-run the Claude code-reviewer before re-running Codex." \
  "requesting-code-review loop names Claude re-review order"

# --- Task 2: completion check (incomplete is not approval) ---
assert_contains "$GATE" "## 4b. Completion check — incomplete is not approval" \
  "gate has a completion-check section"
assert_contains "$GATE" "incomplete is not approval" \
  "gate states incomplete is not approval"
assert_contains "$GATE" "foreground-only" \
  "completion check is grounded in the companion's foreground-only review path"
assert_not_contains "$GATE" "would require changing codex-plugin-cc" \
  "gate no longer claims backgrounding needs a companion change"
assert_contains "$GATE" "Launch in the background" \
  "code recipes launch the review detached"
assert_contains "$GATE" "Watch in the foreground — never idle" \
  "watch loop keeps a blocking foreground call while the review runs"
assert_contains "$GATE" "4 consecutive wait cycles" \
  "watch loop has a bounded cap"
assert_not_contains "$GATE" "adversarial-review --base <BASE_SHA> --wait" \
  "per-task and code-review recipes drop the ignored --wait flag"
assert_not_contains "$GATE" "adversarial-review --base <MERGE_BASE_SHA> --wait" \
  "final whole-branch recipe drops the ignored --wait flag"
assert_contains "$GATE" "600000 ms (10 minutes)" \
  "document reviews pin a concrete explicit timeout"
assert_contains "$GATE" "Write the captured result" \
  "verdict read via capture + verdict-normalize"
assert_contains "$GATE" "CODEX_VERSION" \
  "probe contract captures the companion version"
assert_contains "$GATE" "codex-plugin-cc **1.0.5–1.0.6**" \
  "§4b field paths are pinned to a verified companion version"

assert_contains "$BRAINSTORMING" "using the spec recipe" \
  "brainstorming points at the spec-specific recipe"
assert_contains "$WRITING_PLANS" "using the plan recipe" \
  "writing-plans points at the plan-specific recipe"
assert_contains "$WRITING_PLANS" "the source spec path and the plan path" \
  "writing-plans requires both source spec and plan paths"
assert_contains "$SDD" "using the per-task code recipe" \
  "SDD points per-task gates at the per-task recipe"
assert_contains "$SDD" "using the final whole-branch code recipe" \
  "SDD points final gate at the final recipe"
assert_contains "$REQUESTING_REVIEW" "using the code-review recipe" \
  "requesting-code-review points at the code-review recipe"

assert_not_contains "$GATE" "Read Codex's free-form reply and extract its verdict and findings." \
  "document review no longer relies on free-form extraction"

# --- Task 3: §3 references the round-aware preamble; hand-back reports exit reason + incompletion ---
assert_contains "$GATE" "On a re-review (round 2+), prepend the round-aware preamble from §5" \
  "§3 recipes point at the §5 round-aware re-review preamble"
assert_contains "$GATE" "whether the loop exited by convergence or by hitting the backstop" \
  "hand-back reports the loop exit reason"
assert_contains "$GATE" "whether an incomplete result occurred" \
  "hand-back reports incompletion"
assert_contains "$GATE" "do not let them delay convergence" \
  "out-of-contract Minors on re-review are noted, not fixed"
assert_contains "$GATE" "not re-reviewed by Codex" \
  "backstop-round fixes are flagged as unverified by Codex"
assert_contains "$GATE" "model_reasoning_effort" \
  "hand-back reports the review model and effort"

# --- Task 4: SDD references new caps + completion Red Flag ---
assert_contains "$SDD" "code-gate backstop of 3 rounds" \
  "SDD names the code-gate backstop of 3 rounds"
assert_contains "$SDD" "Treat an unfinished or \"still verifying\" Codex result as approval" \
  "SDD Red Flags echo the incomplete-is-not-approval rule"

# --- Task 5: caller skills reference the new contract ---
assert_contains "$BRAINSTORMING" "document-gate backstop of 4 rounds" \
  "brainstorming names the document-gate backstop"
assert_contains "$WRITING_PLANS" "document-gate backstop of 4 rounds" \
  "writing-plans names the document-gate backstop"
assert_contains "$REQUESTING_REVIEW" "Incomplete Codex results are never treated as approval" \
  "requesting-code-review names the completion contract"

# --- Final-review fix: convergence forbidden while a blocker is still open ---
assert_contains "$GATE" "the round ledger has no still-open blocking findings" \
  "convergence requires the ledger to have no still-open blockers"

# --- Approach gate: brainstorming companion doc contract ---
APPROACH="$REPO_ROOT/skills/brainstorming/codex-approach-gate.md"
assert_contains "$APPROACH" "materially different tradeoffs" \
  "approach gate trigger keys on real architectural/algorithmic alternatives"
assert_contains "$APPROACH" "explicitly requests Codex input" \
  "approach gate honors an explicit partner request even for trivial tasks"
assert_contains "$APPROACH" "EXCLUDE" \
  "approach handoff explicitly excludes Claude's own candidate approaches"
assert_contains "$APPROACH" "proceeds without independent Codex approaches" \
  "approach gate carries its own non-review degradation notice"
assert_contains "$APPROACH" "one-shot" \
  "approach gate is one-shot: no fix loop, no re-review"
assert_contains "$BRAINSTORMING" "codex-approach-gate.md" \
  "brainstorming SKILL.md links the approach gate companion doc"

# --- Round-1 Algorithm Assessment + lock (plan gate) ---
assert_contains "$GATE" "Round-1 Algorithm Assessment" \
  "plan recipe defines the round-1 algorithm assessment"
assert_contains "$GATE" "alternative-suggested" \
  "algorithm assessment output shape carries the alternative-suggested verdict"
assert_contains "$GATE" "advisory input to the controller" \
  "algorithm suggestions are advisory, not blocking"
assert_contains "$GATE" "before applying the loop's exit rule" \
  "algorithm adjudication happens before the approve exit"
assert_contains "$GATE" "Algorithm locked:" \
  "round ledger defines the algorithm lock entry format"
assert_contains "$GATE" "a new blocking (Critical or High) defect in the locked choice" \
  "lock re-opens only for new blocking defects, matching the severity ladder"
assert_contains "$GATE" "Advisory preference" \
  "lock explicitly keeps advisory preference/optimization alternatives locked"
assert_contains "$WRITING_PLANS" "Algorithm Assessment" \
  "writing-plans points at the round-1 algorithm assessment"

echo "Reviewer bootstrap suppression (prompt-level):"
assert_contains "$GATE" "stateless reviewer for this request only" "gate prompts suppress reviewer bootstrap"
assert_contains "$APPROACH_GATE" "stateless reviewer for this request only" "approach gate prompt suppresses reviewer bootstrap"

echo "Gate reliability hardening (6.3.0):"
assert_contains "$GATE" "scripts/codex-preflight" "gate uses codex-preflight"
assert_contains "$GATE" '"stale-broker"' "gate handles stale-broker status"
assert_contains "$GATE" '"not-ready"' "gate handles not-ready status"
assert_contains "$GATE" "base-ref-ok" "gate requires base-ref-ok before launch"
assert_contains "$GATE" "verdict-normalize" "gate uses verdict-normalize"
assert_contains "$GATE" 'launch `adversarial-review` without a passing `base-ref-ok`' "red flag: base validation"
assert_contains "$GATE" 'a `verdict-normalize` result of `approved` counts as approval' "red flag: verdict authority"

echo "Round-1 launch counting (6.4.0):"
assert_contains "$GATE" "Count every round — the first included." "first launch is counted too"

echo "Gate resilience (6.4.0):"
assert_contains "$GATE" "append --class degraded-gate" "degrade branches append class-1"
assert_contains "$GATE" '[status: preflight-error]' "internal failure has its own status token"
assert_contains "$GATE" "append --class incomplete-review" "incomplete final appends class-3"
assert_contains "$GATE" "append --class backstop-fix" "backstop procedure appends class-2"
assert_contains "$GATE" 'gate-round" "$GATE_DIR" --ceiling' "round composition requires gate-round"
assert_contains "$GATE" 'without a `proceed` from `gate-round`' "red flag: no round without proceed"
assert_contains "$GATE" "pending sweep" "healthy preflight re-surfaces pending notice"
assert_contains "$GATE" 'A non-zero `gate-round` exit is an internal failure' "gate-round internal failure maps to backstop"

echo "Review sweep (6.4.0):"
assert_contains "$GATE" "## 7. Review sweep" "sweep section exists"
assert_contains "$GATE" "only on explicit consent" "sweep is consent-gated"
assert_contains "$GATE" 'SWEEP_REPO' "sweep anchors to the source repo"
assert_contains "$GATE" 'never `base..current-HEAD`' "sweep reviews the recorded range"
assert_contains "$GATE" "Route by the event's recorded gate type" "sweep routes by gate type"
assert_contains "$GATE" "never depends on the original briefs" "sweep has a lost-inputs fallback"

echo "Review fidelity (6.5.0):"
assert_contains "$GATE" "scripts/review-dossier" "gate assembles a dossier"
assert_contains "$GATE" "Report every blocking finding you can identify this round; do not reserve findings for later rounds." "exhaustiveness demand"
assert_contains "$GATE" '[out-of-lane]' "out-of-lane findings are reported, never suppressed"
assert_contains "$GATE" "never one entry per lens" \
  "dedup merges to one multi-credited entry"
assert_contains "$GATE" "The lens batch consumes a single logical round" "one gate-round per logical round"
assert_contains "$GATE" 'one `gate-round` call covers composing and launching every lens prompt in the batch' "§5 step-0 counts per logical round"
assert_contains "$GATE" "sequentially in the foreground" "doc lenses stay foreground"
assert_contains "$GATE" "Algorithm Assessment attaches to the feasibility-and-contracts lens" "assessment pinned to one lens"
assert_contains "$GATE" "falls back to the path-based prompts" "dossier degrade attributed"
assert_not_contains "$GATE" "Before ANY companion review invocation in this section" "per-invocation counting is gone"
assert_contains "$GATE" 'add `--require-coverage` to this command' "§4b canonical command carries the round-1 flag"
assert_contains "$GATE" "Never capture a job id after a subsequent launch has occurred" "lens job ids bound at launch"
assert_contains "$GATE" "verdict-normalize --require-coverage" "round-1 captures normalized with the coverage floor"
assert_contains "$GATE" "An empty capture set never approves" "empty set fails closed"
assert_contains "$GATE" '[lens:' "ledger entries carry lens tags"
assert_contains "$GATE" "delivers its lens prompt as the review focus" \
  "code-gate lens prompts reach adversarial-review"
assert_not_contains "$GATE" "The first round uses the prompt as-is." \
  "single-prompt round 1 is gone"
assert_contains "$GATE" "composes the per-lens prompts from the lens fan-out block below" \
  "doc-gate round 1 routes to the fan-out"
assert_contains "$GATE" 'put the Coverage section inside the `summary` field' \
  "structured payloads carry coverage in summary"

echo "Risk tiering (6.6.0):"
assert_contains "$GATE" "the Claude task reviewer and the final whole-branch gates never tier off" \
  "tier relaxation is scoped to the per-task gate"
assert_contains "$GATE" 'record the skip with `ungated-ledger append --class tier-skip' \
  "skips are durably recorded"
assert_contains "$GATE" "<TIER_SKIPS_PATH>" \
  "final recipes deliver the tier-skip summary"

if [ "$FAILURES" -gt 0 ]; then
  echo "STATUS: FAILED ($FAILURES failure(s))"
  exit 1
fi

echo "STATUS: PASSED"
