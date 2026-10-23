# related-tracker-items

**Reads.** The tracker: _(Beads)_ bd issues, _(Kingdone)_ `Gates/`, quests and
notes. _(Neither)_ there is no tracker: skip this check.

**Delta.** The conversation since the `conversation since <ts>` in the row's
detail (turns, automated events and AskUserQuestion answers after that time),
and the new commits or dirty tree. When the status is `unknown` (no transcript
to read), find the line `🛫 preflight check started here · <run>` in your
context and review everything below it; no such line (the context was
compacted) → review the whole session and say so. _(Beads)_ also the issues
changed since the marker: `<n> bd update(s) since <time>` →
`bd list --all --updated-after <time>`, and `<id> updated`. Review only those.

**Findings.** Category `tracker`: every finding of this check, including those
about items this session wrote.

**Moot findings.** Read `preflight-checks findings related-tracker-items`
before you start. When the delta settled one of them — fixed by hand, or the
user said "never mind" — resolve it: `preflight-checks resolve <id> fixed`, or
`preflight-checks resolve <id> discarded "obsolete: <why>"`. No other outcome.
Leave the rest open. `mark` takes only the new findings.

Search the tracker for items related to the work — by the files, the feature,
the names and the terms the branch touches, not only by the id in the branch
name:

- _(Beads)_ open and in-progress bd issues (`bd list --limit 0` — plain
  `bd list` stops at 50 —, `bd search <term>`, `bd show <id>` for their
  dependencies);
- _(Kingdone)_ arrivals in `Gates/`, quests anywhere (in progress, planned or
  someday), and unchecked `- [ ]` items in any note, not only the touched ones.

List each item the work affects, either way:

- this work does it, fully or in part — it can be closed, ticked or updated;
- it depends on this work, or is blocked by it — it should know this lands (a
  note, a link, an unblocked dependency);
- this work depends on it, or conflicts with work it plans;
- it plans something this work changes or makes obsolete.

Each is a finding with a concrete suggested fix: close or tick it, add a note
or link saying what landed, add or drop a dependency, or rewrite the plan. The
issue or quest the branch itself is about is not a finding: `kix:close` marks
it done after the ship — unless this session created or rewrote it (below).

**Items this session wrote.** A session whose work is the tracker itself — it
created a bd issue or an arrival, or rewrote one's title, description, design
or acceptance — has nothing for the code review (no diff: `diff-review` skips),
but those items are its deliverable and get checked here, each one. Find them
from the conversation (every `bd create` / `bd update` it ran, every arrival it
wrote), then `bd show <id>` each. For each item, a finding for anything below:

- **Well-formed** — an imperative title that says what gets done; a description
  with why it exists and what to do, enough for a session that never saw this
  conversation; a real type and priority; acceptance criteria when it is more
  than a one-liner; `--parent` or deps where the conversation or the tracker
  puts it (an epic it belongs under, what blocks it); what the user actually
  said, not a narrower or broader version of it.
- **Related** — search the tracker for it the same way as above (its files,
  feature, names and terms): a duplicate or near-duplicate (merge, or close one
  as a duplicate), an item it overlaps, an epic it belongs under, an item it
  depends on or blocks. Each missing link is a finding.
- **Unanswered** — open questions the item leaves: a choice it names but does
  not make, a "TBD", a design decision the conversation raised and nobody
  settled. The fix is to ask the user now and write the answer into the item.
- **Pitfalls** — what the plan misses: edge cases, callers or sibling configs
  it will have to touch, other sessions or branches working on the same thing,
  a migration or reinstall it will need. The fix is a line in the item, not new
  work.

Fixes for these are `bd update` (or an edit to the arrival), never code. A
session that only wrote tracker items still runs `conversation-leftovers`,
`unraised-follow-ups` and `post-landing-steps` as usual; the unanswered
questions and the pitfalls about the item go in this check instead, so nothing
is reported twice.
