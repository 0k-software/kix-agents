# conversation-leftovers

**Reads.** The session's conversation.

**Delta.** the conversation since the `conversation since <ts>` in the row's
detail: the turns, automated events and AskUserQuestion answers after that
time. When the row's status is `unknown` (no transcript to read), find the line
`🛫 preflight check started here · <run>` in your context and review everything
below it; no such line (the context was compacted) → review the whole session
and say so.

**Findings.** Category `conversation`: the leftovers listed below.

**Moot findings.** Read `preflight-checks findings conversation-leftovers`
before you start. When the delta settled one of them — fixed by hand, or the
user said "never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

Preflight's own process questions (Decide, Verdict, rerun) are not leftovers;
only what the answers say is. Questions about findings are
`findings-leftovers`' job, so nothing is reported twice.

Read the session and list:

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

This check's progress line tallies each of the six kinds, e.g.
`✅ 3/15 Conversation — asks 0 · unanswered 0/0 · deferred 0 · promised 0 · inferred 1`;
`unanswered x/y` is questions the user left unanswered / questions you left
unanswered.
