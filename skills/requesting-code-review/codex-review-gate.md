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

## Routes

**Read your whole route before you start.** A route is a *set*, not a sequence.
The gate's §-references point in both directions — §3 names §5's round counter
and §4b's recovery path, §4b names §3's watch loop, §5 names §3's prompt and
`GATE_DIR` — so there is no order in which every reference points backwards.
Load the whole set first and every reference resolves against context you
already hold. Section files never send you to another file.

| Caller | Route |
|--------|-------|
| approach gate | `gate-preflight` |
| spec gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop` |
| plan gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-document`, `gate-findings`, `gate-fix-loop` |
| per-task code gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| final whole-branch gate | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| ad-hoc code review | `gate-preflight`, `gate-setup`, `gate-output-schema`, `gate-lenses`, `recipe-code`, `gate-findings`, `gate-fix-loop` |
| review sweep | `gate-preflight`, `gate-sweep`, plus the route for the gate type each queued event records |

The approach gate's route is one file: its entire need is §1 and §2, which is
why they share a file. The sweep's route is conditional by design — it
dispatches by recorded gate type and inherits that type's route.
