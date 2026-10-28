# kxa-a9i — Show what changed at the preflight rerun question

The approved design, as written into the bead's design field (2026-10-24).

Amended 2026-10-28 (kelvinst, after the live check). Supersedes the parts below
where they disagree:

- No "Show me what changed" option. The Verdict's own status call takes
  `--diff-html <file> [--from <first step 5 commit>]` and writes the diff page
  only when something is unreviewed (step 5 commits, or
  `unreviewed-bead-changes` reads finding or stale), naming it in a `diff-page`
  row. A **changed** verdict links that page in the reply as a `file://` URL
  (the app opens it in its browser; a bare path shows the HTML source). It
  doesn't open the page itself, which didn't work in the demo, and prints no
  diff text. The rerun question keeps I reviewed / skip my review / not now.
- The page (`diff --html`): the commits in full, no stat fallback, and every
  bead change. Inside each changed line, the changed words are highlighted from
  `git diff --word-diff=porcelain`, like GitHub. One self-contained HTML file
  with dark mode.
- Scope: only this session's beads count. bd records no session, so they are
  read from the session's transcript: ids in the bd write commands it ran (Bash
  tool, or the user's `!` shell) and the ids its `bd create`s printed, plus
  every bead a dependency links to them, either way. Other sessions' changes
  show only as a "not shown" count. With no transcript, all beads count, with
  the other-sessions warning.

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
- Beads: every issue changed in the window, read through dolt sql as
  dolt_diff(<mark>, WORKING, <table>) for issues, dependencies, labels and
  comments (bd diff --json omits deps/labels/comments — tested; dolt diff -r
  json prints long text stored out of row as raw {"Buf", "Addr"} blobs — found
  on the real tracker 2026-10-26): created as + lines, deleted as - lines,
  modified as only the changed fields (long text diffed line by line),
  deps/labels/comments as +/- lines under their issue. Always in full.
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
