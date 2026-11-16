# Backgrounding and TODO Lists (2026-10-13)

I use Zed as one of my primary editors and I see that often it appears that SDD within hyperpowers causes Zed to look like nothing is happening (i.e. there is no longer an indicator by the task). This can be confusing and the user will often ask to "resume" when the task is running. Please investigate and address this.

Status (2026-11-16): fixed across 6.17.0 to 6.18.1 (the SDD stop guard and the dispatch guard keep the turn open while work runs).

# Parallel development on the same machine

Do we specifically address ways to faciliate parallel development on the same machine? This falls into two categories:

1. Working on multiple tasks in parallel during SDD in the same slice if they do not block each other.
2. Working on two separate slices of the same plan if they do not block each other.

Let's also brainstorm how it would be possible to swap between parallel development tasks to brainstorm, ask/answwer questions or grant permissions.

Status (2026-11-16): item 2 (separate slices of one plan in parallel sessions) shipped in 6.18.0. Item 1 (parallel tasks under one controller) and the question relay are still deferred; see the parallel-development spec's deferred items.

# Stale brokers

I sometimes get asked to rename stale brokers. Can we allow this through permissions? Is there a risk to doing this that might be unacceptable?

e.g.
mv ~/.claude/plugins/data/codex-openai-codex/state/predict-before-structure-6ad0890d6c0327f3/broker.json ~/.claude/plugins/data/codex-openai-codex/state/predict-before-structure-6ad0890d6c0327f3/broker.json.stale-$(date +%s)

Status (2026-11-16): answered, do not allow the rename. Renaming a live broker record orphans its broker and its jobs. 1669b4a3 and the 6.19.0 companion-sandbox fix remove the cause: the prompt came from companion calls running inside the Bash sandbox, which misread a live broker as stale.

# User Questions (2026-11-12)

Now when the user is posed a question when using hyperpowers in Zed, it looks as if it is still busy. It should show a dot indicator to indicate there's a message for the user.

Status (2026-11-16): still open. Next step is a transcript diagnosis, as the 2026-11-10 Zed work did (consolidation register item 2).
