# Fix Subagent Prompt Template

You are dispatched for the FINAL-REVIEW fix wave only: the per-task fix loop
resumes the original implementer (rounds 1-3), applies a de-minimis fix
itself under the carve-out's bounds, or dispatches a takeover implementer
(rounds 4-5) — it never uses this prompt. You fix the final review's
blocking findings in one wave; exactly one scoped re-review follows.

```
Subagent (general-purpose):
  description: "Fix findings for Task N: [task name]"
  model: [MODEL — REQUIRED: match the smallest model the fix demands;
         single-file mechanical fixes take the cheapest tier]
  prompt: |
    You are fixing review findings for [Task N: task name | the final whole-branch review wave].

    ## Findings (complete list for this wave)

    [EVERY finding this wave must address — severity, location, issue,
    and the reviewer's recommendation. Never dispatch a partial list.]

    ## Scope

    Files you may touch: [exact paths]. If the fix genuinely requires
    another file, STOP and report BLOCKED with the reason — do not expand
    scope on your own.
    Never execute fixture or scenario scripts against a real checkout — run them in a scratch directory.

    ## Context

    Task brief (per-task waves) or plan/branch context (final waves): [BRIEF_OR_BRANCH_CONTEXT]
    Implementer report so far: [REPORT_FILE]

    ## Tests

    Covering command(s): [exact command(s) — OR the line
    `no covering command: <rationale>` plus what the controller will do
    instead]. When commands are named: re-run them after your fix and put
    the output in your report. the controller re-runs your covering
    command; a report that doesn't match its output is a failed task.

    ## Commit hygiene

    - stage ONLY the files named in this dispatch
    - NEVER `git add -A` or `git add .`
    - nothing under docs/ planning paths (specs/plans) may be staged
    - no AI-attribution lines in the commit message

    ## Report

    APPEND your fix note to [REPORT_FILE]: what changed per finding, why,
    and the exact covering command(s) run with their final output lines (or the dispatch's `no covering command:` line restated). For final-review waves, [REPORT_FILE] is
    the final-review findings file named in the dispatch. Then return ONLY:
    Status (DONE|BLOCKED), commit SHA + subject, one-line test summary. The controller
    re-runs your covering command; a report that doesn't match its output is a failed task.
```
