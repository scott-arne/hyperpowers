### Required document-review output

For spec and plan reviews, require this exact shape so Claude does not have to
infer a verdict from prose:

```markdown
Verdict: approve|needs-attention

Blocking Findings:
- severity: critical|high
  title: ...
  evidence: <file>:<line references>
  issue: ...
  recommendation: ...

Non-blocking Findings:
- severity: medium|low
  title: ...
  evidence: <file>:<line references>
  issue: ...
  recommendation: ...

Cannot verify:
- requirement: ...
  reason: ...
  needed evidence: ...

Summary: ...
```

Every finding should include line references when the artifact has stable line
numbers. If there are no findings in a section, write `None`.

For code recipes, prefer `--json` and read the structured `result` payload when
present. If the companion renders text instead, extract the same verdict,
findings, and severity fields.

