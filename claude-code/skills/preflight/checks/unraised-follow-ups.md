# unraised-follow-ups

**Reads.** The work done — the diff, the conversation, the touched files — and
the tracker, for what nobody raised.

**Delta.** The new commits or dirty tree in the row's detail, and the
conversation since the `conversation since <ts>` in the row's detail: the
turns, automated events and AskUserQuestion answers after that time. When the
row's status is `unknown` (no transcript to read), find the line
`🛫 preflight check started here · <run>` in your context and review everything
below it; no such line (the context was compacted) → review the whole session
and say so.

**Findings.** Categories `related`, `idea`, `next-step` and `pitfall`, as
listed below.

**Moot findings.** Read `preflight-checks findings unraised-follow-ups` before
you start. When the delta settled one of them — fixed by hand, or the user said
"never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

List what nobody raised: nothing already in the conversation or in the tracker
(`related-tracker-items`) goes here:

- related things the change touches or should touch but nobody mentioned (other
  callers, sibling configs, docs, other repos or branches that depend on it);
- ideas the work suggests — improvements worth having, not needed now;
- next steps — the natural follow-up work;
- possible pitfalls — how it could break, be misused or surprise later (edge
  cases, environments, concurrency with other sessions or branches, upgrades).

Each is a finding like any other, with a concrete suggested fix: usually the
defer option (a task or an arrival), or doing it now when it is small. Only
real, specific items — no generic advice; say what triggered each.
