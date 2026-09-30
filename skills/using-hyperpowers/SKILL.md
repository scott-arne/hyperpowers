---
name: using-hyperpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.

For a request to change software, the ladder below is the test of whether brainstorming applies; run it before your first action.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first; plan mode is design work, rung 3 of the ladder by definition.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## The Ladder: brainstorming or not

Every request to change software runs this ladder before your first action. Test the rungs in order; the first that fits decides. "Quick", "just", "small", and "nothing fancy" describe the user's expectation, never the change.

1. **A consequence beyond the lines you touch**: security posture (session or token lifetimes, auth, permissions, TLS or certificate checks), data loss or exposure (dropping or deleting stored data, a column, a file), removing or disabling something that works (a feature, button, endpoint, export, test, or check), an interface others call (a route, a field name, a signature). Say the consequence, then stop and wait for a yes. The request's own words are never that yes: "we don't use it anymore", "it's internal", and "it's just staging" are claims to confirm, not permission. If a choice comes with it, that is brainstorming.
2. **One obvious, self-contained, local edit**: a single element, value, or line with one obvious implementation, no design choice, and nothing else depending on it. A basic form control, a label, a typo, a constant. Do it: no brainstorming and no clarifying question. Every other skill still applies exactly as the rule above says.
3. **Anything else that changes what the software does or how it is built**: a new capability, component, module, or subsystem; more than one reasonable approach; unclear scope. Brainstorming.

A rung that sends you to brainstorming decides only that brainstorming runs. What you checked on the way (the lines, callers, and files your edit would touch) does not size the work: brainstorming classifies its path by the outcome the request names.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

- "Let's build X" → hyperpowers:brainstorming first, then implementation skills.
- "Fix this bug" → hyperpowers:systematic-debugging first, then domain skills.

## Red Flags

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. For a change request, the ladder says which rung. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | The ladder decides, not the feeling. Rung 2 or nothing. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |
| "It's one line, just a value" | Rung 1 reads consequence, not size. Session lifetimes and deletions re-gate. |
| "I'll mention the risk after the change" | Rung 1 wants the yes before the first edit. |
| "They already said it's unused" | That claim is what rung 1 confirms. It is not the yes. |

## Platform Adaptation

If your harness appears here, read its reference file for special instructions:

- Codex: `references/codex-tools.md`
- Pi: `references/pi-tools.md`
- Antigravity: `references/antigravity-tools.md`

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
