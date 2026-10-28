---
name: ship
description:
  Use when the user types /kix:ship, or asks to put the current branch's work on
  the default branch ("manda pra main", "mergear na main", "sobe pra main",
  "ship"), or when another skill needs the branch's commits in the default
  branch.
---

# Ship to the default branch

"Merge into main" means GitHub's **rebase and merge**, done in two parts: the
`kix:preflight` skill rebases the branch onto the default branch and reviews
it, and ship only fast-forwards the default branch to the checked branch — no
merge commit, flat history. Ship never rebases and never reviews on its own; it
runs `kix:preflight` for both.

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
as `kix:preflight`'s _Progress_ says: the preflight steps are 1–12, and steps
2–5 below are 13–16 of 16 (of 18 when `kix:close` called ship).

1. **Preflight.** Run the `kix:preflight` skill, every time — even when every
   check is fresh (preflight skips them then, but still rebases and checks the
   branch again). Its verdict decides:

   - **Changed** or **Open** → stop here. Preflight already told the user what
     to do; add nothing, ship nothing.
   - **Clear** → go on.

   A clear branch with no commits past `<base>` (`git rev-list --count
   <base>..HEAD` prints `0` — e.g. a session that only wrote bd issues) has
   nothing to ship: print `⏭️` lines for steps 2–4 (`nothing to ship`) and
   step 5's line says `0 commits — <default> unchanged`. Never ask to ship an
   empty range.

2. **Confirm.** Show the branch diff from `<base>` the way `kix:preflight`'s
   _Showing the diff_ says — the compare link in the reply, never in the
   question — say what "Ship" does, then ask with AskUserQuestion: "Reviewed —
   can I ship?" Options:

   - "Ship" — "Not a merge: no merge commit. The branch was already rebased
     onto `<default>`, so its commits land on top of it as they are — flat
     history.";
   - "Not yet" — "I still have other things to do in this session."

   Anything but "Ship" → stop.

3. **Gate.** Right before pushing, recheck — the user may have taken a while:

   ```bash
   git status --porcelain
   git fetch origin
   preflight-checks --no-fetch --format tsv
   ```

   Stop unless `uncommitted-changes` is `pass`, `behind-default-branch` is
   `pass`, `diff-review` is `fresh` or `skip`, `findings-leftovers` is `pass`,
   and `unreviewed-bead-changes` is `pass` or `skip`. The stop message lists
   which of them failed. After the ⚠️ block, say in the reply what changed
   since the preflight (uncommitted changes / `<default>` moved / diff not
   reviewed / open findings / bead changes not reviewed) with the branch diff
   from `<base>` as its link, then ask "Run `<command>` again?" with
   `kix:preflight`'s _Verdict_ **changed** rerun options (reviewed · skip my
   review · not now) — this stop opens no diff page; on "skip my review", the
   ⚠️ item names the branch range `<base>..HEAD`. `<command>` as _Verdict_
   defines it (`/kix:close` when close called ship). Never rebase or review
   here to fix it.

4. **Push the default branch and the branch.**

   ```bash
   git push origin HEAD:<default>
   git push --force-with-lease origin HEAD
   ```

   The push to `<default>` is a fast-forward. If it is rejected, `<default>`
   moved: stop with the step 3 message.

   On `<default>` itself (no branch), push is just `git push`.

5. **Check.**

   ```bash
   git fetch origin
   git merge-base --is-ancestor HEAD <base> && echo IN_DEFAULT
   ```

   Report the commits that landed (`git log --oneline <old base>..HEAD`).

## Common mistakes

- Skipping preflight because every check is already fresh.
- Going past a **changed** or **open** verdict.
- Rebasing, merging the default branch, or reviewing from ship itself instead
  of through preflight.
- Pushing without the "Ship" answer.
- Shipping with a stale `diff-review` or open findings.
- Hardcoding `main` instead of the detected default branch.
- Restarting the progress count at ship's own steps instead of going on from
  preflight's.
- Force-pushing the default branch — never.
