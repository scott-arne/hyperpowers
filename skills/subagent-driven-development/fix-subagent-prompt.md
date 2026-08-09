# Fix Subagent Prompt Template

Use this template for EVERY fix dispatch — per-task review findings, Codex
gate findings, and final-review fix waves alike. One fixer per findings
wave, never one per finding.

```
Subagent (general-purpose):
  description: "Fix findings for Task N: [task name]"
  model: [MODEL — REQUIRED: match the smallest model the fix demands;
         single-file mechanical fixes take the cheapest tier]
  prompt: |
    You are fixing review findings for Task N: [task name].

    ## Findings (complete list for this wave)

    [EVERY finding this wave must address — severity, location, issue,
    and the reviewer's recommendation. Never dispatch a partial list.]

    ## Scope

    Files you may touch: [exact paths]. If the fix genuinely requires
    another file, STOP and report BLOCKED with the reason — do not expand
    scope on your own.

    ## Context

    Task brief: [BRIEF_FILE]   Implementer report so far: [REPORT_FILE]

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
    and the covering-test output. Then return ONLY: Status
    (DONE|BLOCKED), commit SHA + subject, one-line test summary.
```
