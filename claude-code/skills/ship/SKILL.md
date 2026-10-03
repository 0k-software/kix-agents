---
name: ship
description:
  Use when the user types /ship, or asks to put the current branch's work on
  the default branch ("manda pra main", "mergear na main", "sobe pra main",
  "ship"), or when another skill needs the branch's commits in the default
  branch.
---

# Ship to the default branch

"Merge into main" means GitHub's **rebase and merge**, done in two parts: the
`preflight` skill rebases the branch onto the default branch and reviews it,
and ship only fast-forwards the default branch to the checked branch — no merge
commit, flat history. Ship never rebases and never reviews on its own; it runs
`preflight` for both.

**Language.** Reply in the language the user is speaking.

**Default branch.** Never assume `main`:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null \
  || { git remote set-head origin --auto >/dev/null && git symbolic-ref --short refs/remotes/origin/HEAD; }
```

Below, `<base>` is that ref (e.g. `origin/main`) and `<default>` is the branch
name without `origin/`.

## Steps

Print a progress line when each step ends, and a ❓ line before each question,
as preflight's _Progress_ says: the preflight steps are 1–11, and steps 2–5
below are 12–15 of 15 (of 17 when `close` called ship).

1. **Preflight.** Run the `preflight` skill, every time — even when HEAD
   already carries a check mark (preflight skips its git-only checks then, but
   still rebases and reruns the ones that read the session or bd). Its verdict
   decides:

   - **Changed** or **Open** → stop here. Preflight already told the user what
     to do; add nothing, ship nothing.
   - **Clear** → go on.

   A clear branch with no commits past `<base>` (`git rev-list --count
   <base>..HEAD` prints `0` — e.g. a session that only wrote bd issues) has
   nothing to ship: print `⏭️` lines for steps 2–4 (`nothing to ship`) and
   step 5's line says `0 commits — <default> unchanged`. Never ask to ship an
   empty range.

2. **Confirm.** Show the branch diff from `<base>` the way preflight's _Showing
   the diff_ says — the compare link in the reply, never in the question — say
   what "Ship" does, then ask with AskUserQuestion: "Reviewed — can I ship?"
   Options:

   - "Ship" — "Not a merge: no merge commit. The branch was already rebased
     onto `<default>`, so its commits land on top of it as they are — flat
     history.";
   - "Not yet" — "I still have other things to do in this session."

   Anything but "Ship" → stop.

3. **Gate.** Right before pushing, recheck — the user may have taken a while:

   ```bash
   git status --porcelain
   git fetch origin
   git fetch origin refs/notes/checks:refs/notes/checks 2>/dev/null || true
   git merge-base --is-ancestor <base> HEAD && echo UP_TO_DATE
   git notes --ref=checks show HEAD 2>/dev/null | head -1
   ```

   A dirty tree, no `UP_TO_DATE`, or a first note line not starting with
   `checked` → stop. After the ⚠️ block, say in the reply what changed since
   the preflight (dirty tree / `<default>` moved / HEAD not checked) with the
   branch diff from `<base>` as its link, then ask "Run `<command>` again?"
   with the same three options as preflight's _Verdict_ **changed** rerun
   question (reviewed · skip my review · not now); on "skip my review", the ⚠️
   item names the branch range `<base>..HEAD`. `<command>` as _Verdict_ defines
   it (`/close` when close called ship). Never rebase or review here to fix it.

4. **Push the default branch, the branch and the notes.**

   ```bash
   git push origin HEAD:<default>
   git push --force-with-lease origin HEAD
   git push origin refs/notes/checks
   ```

   The push to `<default>` is a fast-forward. If it is rejected, `<default>`
   moved: stop with the step 3 message. If the notes push is rejected, run
   `git fetch origin refs/notes/checks:refs/notes/checks-remote`,
   `git notes --ref=checks merge -s union refs/notes/checks-remote`, and push
   again.

   On `<default>` itself (no branch), push is just `git push` plus the notes.

5. **Check.**

   ```bash
   git fetch origin
   git merge-base --is-ancestor HEAD <base> && echo IN_DEFAULT
   ```

   Report the commits that landed (`git log --oneline <old base>..HEAD`).

## Common mistakes

- Skipping preflight because HEAD already carries a `checked` mark.
- Going past a **changed** or **open** verdict.
- Rebasing, merging the default branch, or reviewing from ship itself instead
  of through preflight.
- Pushing without the "Ship" answer.
- Shipping a HEAD whose first note line does not start with `checked`. Old
  `reviewed` notes in `refs/notes/review` no longer count.
- Hardcoding `main` instead of the detected default branch.
- Restarting the progress count at ship's own steps instead of going on from
  preflight's.
- Force-pushing the default branch — never.
