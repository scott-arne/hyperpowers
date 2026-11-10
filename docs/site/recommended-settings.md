---
sources: skills/writing-plans/SKILL.md README.md docs/hyperpowers/2026-11-03-cost-reduction-6-16-2-eval-evidence.md skills/brainstorming/SKILL.md skills/subagent-driven-development/SKILL.md skills/writing-skills/SKILL.md
source-digest: e58ee6810705
---

# Recommended settings

These tips apply to Claude Code. Each one lowers cost, and the first tip explains what the skills do after a compaction.

## Why sessions cost what they do

Each model call re-sends the whole conversation. In a long session most of the cost is reading and writing that cached context, so cost follows the size of the context multiplied by the number of calls. Hyperpowers sessions run long: brainstorming, planning, and {doc}`skills/subagent-driven-development` can share one session for days.

## Tip 1: lower the auto-compact window to 400K

Add this to `~/.claude/settings.json`:

```json
{
  "autoCompactWindow": 400000
}
```

The environment variable `CLAUDE_CODE_AUTO_COMPACT_WINDOW` sets the same value.

On models with a 1M-token window, Claude Code otherwise compacts only near 968K tokens. In a replay of a month of long sessions, a 400K window cut cost by about 28%. A 300K or 200K window saved only 4 or 7 points more, while adding 1.5 or 2.6 times as many extra compactions as the 400K window, and each compaction drops detail.

After a compaction, Claude Code re-attaches only the first 20,000 characters of each skill that the session used. {doc}`skills/brainstorming` and {doc}`skills/subagent-driven-development` are long skills, and both tell the agent to read their full text again after every compaction, so that they do not keep running from the cut copy. In testing at a forced 100K window, where compactions come far more often than at 400K, agents re-read after 98% of compactions in subagent-driven-development and after 100% in brainstorming. The 400K window itself was not measured. It leaves about 300K of headroom after each compaction.

{doc}`skills/writing-skills` is also longer than 20,000 characters and does not yet carry the re-read instruction.

Do not go below about 200K. At very small windows a session can compact again right after the re-read and loop.

## Tip 2: keep one-hour prompt caching

If `ENABLE_PROMPT_CACHING_1H=1` is set, leave it set. Sessions pause for five to sixty minutes while subagents and reviews run, and with a five-minute cache each such pause rewrites the whole context. The same replay cost about 56% more with five-minute caching.

## Tip 3: run `/clear` between planning and execution

When the plan is written, run `/clear` before starting subagent-driven development. The writing-plans skill starts execution right after it saves the plan, so to clear first, stop the agent at the handoff, run `/clear`, then ask it to execute the plan file. The spec and plan are on disk, so the execution session starts from a small context.

## What these settings change

These settings change token volume. How that shows up depends on your plan: per-token billing or subscription usage limits.
