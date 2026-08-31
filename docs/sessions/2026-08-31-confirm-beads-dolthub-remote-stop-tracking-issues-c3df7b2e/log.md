---
saved_at: 2026-08-31T20:29:34Z
session_id: c3df7b2e-dca3-4e98-a43d-a74d503e5713
transcript: transcript.jsonl.gz
---

# Confirm beads DoltHub remote; stop tracking issues.jsonl

> **Source:**
> `~/.claude/projects/-Users-kelvinstinghen-Developer-worktrees-kix-agents-kicks-commit-message-skill-3b78aa/c3df7b2e-dca3-4e98-a43d-a74d503e5713.jsonl`
> (local; not a public link).

## Goal

Confirm how this repo's beads instance is wired (local vs DoltHub), work out
whether `.beads/issues.jsonl` still needs to be committed, and stop the
auto-exported JSONL from leaking back into git.

## 2026-08-31 — update

- **Question: is beads pointed at DoltHub instead of local?** Answer: both, and
  the distinction matters. `.beads/config.yaml` carries
  `sync.remote: "https://doltremoteapi.dolthub.com/kelvinst/kix-agents"`, and
  `bd dolt remote list` confirms `origin` at that URL. But
  `.beads/metadata.json` says `"dolt_mode": "embedded"` with database `kxa` —
  so the local embedded Dolt DB is the source of truth and DoltHub is the
  remote reached via `bd dolt push` / `bd dolt pull`. Not a replacement for
  local storage.
- **Follow-up: does the JSONL still need committing?** No.
  `git ls-files .beads/` returns only `.gitignore`, `README.md`, `config.yaml`,
  `hooks/*`, `metadata.json` — no `issues.jsonl`. It was removed as part of
  kxa-8g7 (the migration to the DoltHub remote); its last appearance in history
  is commit `860f4ad release: v0.2.3`, which deleted it. Issue data now travels
  over `bd dolt push`/`pull`, code over `git push` — two separate paths.
- **User pushed back: "but on main, there is a jsonl."** Investigated and they
  were right about the file, wrong about its state. `git ls-tree origin/main`
  and local `main` both show no `issues.jsonl` in the tree — but the main
  checkout at `~/Developer/kix-agents` had it **staged**:
  `git status --short -- .beads/` → `A  .beads/issues.jsonl` (62KB, modified
  the same day).
- **Root cause.** Two things combine: bd auto-exports `.beads/issues.jsonl`,
  and nothing in `.beads/.gitignore` ignores it (its trailing comment even
  notes config files are tracked by default because no pattern covers them).
  The `.beads/hooks/pre-commit` Prettier gate then runs a blanket `git add .`,
  so the regenerated export re-stages itself and would ride into the next
  commit on main. `.git/info/exclude` was empty, so no fork-protection rule was
  catching it either.
- **Fix, chosen over alternatives.** Considered leaving it tracked (rejected —
  contradicts the kxa-8g7 decision to make Dolt the source of truth and would
  reintroduce merge noise) and a negation pattern (rejected —
  `.beads/.gitignore` explicitly warns that negations override fork protection
  in `.git/info/exclude`). Went with the plain two-step:
  1. `git -C ~/Developer/kix-agents rm --cached .beads/issues.jsonl` — unstages
     it in the main checkout, leaves the file on disk (now `?? `).
  2. Added a plain ignore line at `.beads/.gitignore:56-57`:
     `# Auto-exported issue data (source of truth is the Dolt remote, not git)`
     / `issues.jsonl`, placed just above the existing `backup/` rule.
- **Verified:** `git check-ignore -v .beads/issues.jsonl` →
  `.beads/.gitignore:57:issues.jsonl`. Noted the caveat that the main checkout
  still shows `?? .beads/issues.jsonl` because worktrees have separate working
  copies — the rule only bites there once this change lands on `main`.
- Session ran in `caveman` ultra mode throughout; this log was written directly
  rather than via the caveman compressor.

## Open Questions

- [ ] Should `.beads/interactions.jsonl` (also present untracked in the main
      checkout) get the same treatment, or is it already covered? It is —
      `.beads/.gitignore` lists it under "Interactions log (runtime, not
      versioned)" — but worth confirming no other bd auto-export is unignored.

## Action Items

- [ ] Land this `.beads/.gitignore` change on `main` so the ignore rule takes
      effect in the primary checkout (it currently only applies inside the
      `kicks-commit-message-skill-3b78aa` worktree).
- [ ] After merging, re-check `git status` in `~/Developer/kix-agents` to
      confirm `.beads/issues.jsonl` disappears from the untracked list.
