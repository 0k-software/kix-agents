# conversation-leftovers

**Reads.** The session's conversation; the data lists the prompts since the
marker.

**Delta.** The conversation since the marker: the prompts listed, and what
happened after them.

**Findings.** Category `conversation`. Preflight's own process questions
(Decide, Verdict, rerun) are not leftovers — only what the answers say is.
Questions about findings are `findings-leftovers`' job, so nothing is reported
twice. List:

- things the user asked for that were not done, or were done only in part;
- questions you asked that the user never answered — an AskUserQuestion the
  user skipped, dismissed or rejected is unanswered;
- questions the user asked that you never answered, or answered only in part —
  a question buried in a longer message counts;
- things the user deferred ("later", "tomorrow", "I'll look at it");
- follow-ups you promised;
- inferred loose ends: what the work implies but nobody said (run it for real,
  update a doc or note the change contradicts, a memory to record; _(Kingdone)_
  test it in Obsidian). Say where each came from.

If the conversation was summarized earlier, say so: findings before the summary
are only as good as the summary.
