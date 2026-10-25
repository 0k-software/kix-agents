# kxa-a9i — Show what changed at the preflight rerun question

The approved design, as written into the bead's design field (2026-10-24).

Approved 2026-10-24 (kelvinst, brainstorm session).

Where: only preflight's Verdict **changed** rerun question gets a 4th option
"Show me what changed" (ship and close reach it through preflight; the
open-verdict question and ship's Gate stop do not — nothing this run applied is
waiting there). It prints the diff, then asks the same question again without
the show option.

Verdict: any unseen bead change in the window makes the verdict **changed** —
Fix-job edits, the session's own bd writes, manual edits — not just Fix-job
ones.

Window: from the review mark; with no review yet, from the session-start mark.

- Session-start mark: a SessionStart hook records the beads DB's dolt HEAD in
  the per-session store (kix/checks/<session>/ under the git common dir).
- Review mark: moved to dolt HEAD on "I reviewed" and on a **clear** verdict;
  "Run again, skip my review" leaves it.

Output:

- Code: this run's step-5 commits, git diff <first>^..HEAD in a diff block when
  ~80 lines or fewer, else --stat; plus a labeled Markdown link with a literal
  ^.
- Beads: every issue changed in the window from dolt diff -r json <mark> HEAD
  (bd diff --json omits deps/labels/comments — tested): created as + lines,
  deleted as - lines, modified as only the changed fields (long text diffed
  line by line), deps/labels/comments as +/- lines under their issue. Always in
  full.
- ⚠️ "other sessions also touched beads since your last review" when another
  session's transcript (~/.claude/projects/<encoded repo path>_/_.jsonl, not
  this one) changed in the window. bd records no session id on writes; tagging
  BEADS_ACTOR was rejected (pollutes created_by, labels/comments still
  unattributed) — revisit if missed.

Built as: preflight-checks subcommands (bd-mark start|review, diff) whose
output can later feed kix checkpoints unchanged; the SessionStart hook; a make
test suite on a throwaway DB that pins bd's dolt layout
(.beads/embeddeddolt/<db>, main checkout only); preflight SKILL.md Verdict
text; CLAUDE.md + CHANGELOG entries.

Not in scope: per-session filtering; sending output to kix checkpoints.
