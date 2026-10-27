# unraised-follow-ups

**Reads.** The work done — the diff, the conversation, the touched files — and
the tracker, for what nobody raised.

**Delta.** New commits other than Fix commits, the dirty tree, and the prompts
since the marker.

**Findings.** Categories `related`, `idea`, `next-step` and `pitfall`. Nothing
already in the conversation or in the tracker (`related-tracker-items`) goes
here:

- related things the change touches or should touch but nobody mentioned (other
  callers, sibling configs, docs, other repos or branches that depend on it);
- ideas the work suggests — improvements worth having, not needed now;
- next steps — the natural follow-up work;
- possible pitfalls — how it could break, be misused or surprise later (edge
  cases, environments, concurrency with other sessions or branches, upgrades).

Each has a concrete suggested fix: usually the defer option (a task or an
arrival), or doing it now when it is small. Only real, specific items — no
generic advice; say what triggered each.
