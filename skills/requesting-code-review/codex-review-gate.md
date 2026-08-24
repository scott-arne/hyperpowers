# Codex Review Gate

A shared stage-gate that asks Codex (via codex-plugin-cc) to review an artifact
**after** Claude has done its own review/refine/fix pass and **before** the user
is re-engaged or the work is declared complete. Referenced by brainstorming,
writing-plans, subagent-driven-development, and requesting-code-review.

**Claude Code only.** Run this gate only under Claude Code. In any other harness,
skip it silently — do not run the preflight, do not emit the notice.

## Sections

| File | Contents |
|------|----------|
| [gate-preflight.md](gate-preflight.md) | §1 preflight availability; §2 no-Codex notice |
| [gate-setup.md](gate-setup.md) | §3 shared setup: `GATE_DIR`, dossier assembly, the foreground rule |
| [gate-output-schema.md](gate-output-schema.md) | §3 the Required document-review output block |
| [gate-lenses.md](gate-lenses.md) | §3 round-1 lens fan-out, charters, launch discipline |
| [recipe-document.md](recipe-document.md) | §3 spec and plan recipes; Round-1 Algorithm Assessment |
| [recipe-code.md](recipe-code.md) | §3 task, final, and ad-hoc code recipes |
| [gate-findings.md](gate-findings.md) | §4 severity mapping; §4b completion check |
| [gate-fix-loop.md](gate-fix-loop.md) | §5 fix-and-re-review loop and backstops; §6 hand back |
| [gate-sweep.md](gate-sweep.md) | §7 review sweep |
