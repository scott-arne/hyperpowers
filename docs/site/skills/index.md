# Skills

Skills trigger automatically: the agent matches your request against each skill's description and loads the ones that apply. This page lists the skills by category, with what each does and when it triggers.

## Process

| Skill | What it does | Triggers when |
|---|---|---|
| {doc}`brainstorming` | Classifies the request, asks questions one at a time, and gets your approval of a design before any code is written. | You ask for a feature, a component, or a behavior change. |
| {doc}`writing-plans` | Turns an approved design into bite-sized tasks with exact files, steps, and risk tiers. | You have a spec or requirements for a multi-step task. |
| {doc}`executing-plans` | Works through a written plan in the current session and stops when blocked. | You have a plan to run in a separate session, or subagents are unavailable. |
| {doc}`subagent-driven-development` | Dispatches a fresh implementer subagent per task and reviews each task and the whole branch. | You have a plan with mostly independent tasks to run in the current session. |
