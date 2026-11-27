---
name: ship-to-develop
description: Finishes a task in this repository by committing it on a feat/ branch, merging into develop and, with separate confirmation, pushing develop — staging only the files this task changed. Use when the user asks to ship, merge into develop or push this task, or types /ship-to-develop. A plain "commit" request is not enough to push.
---

# ship-to-develop — commit → sync develop → merge into develop → (confirm) push

Asking for this skill approves committing and merging into the local `develop`. **Pushing is a separate approval**: unless the user's request explicitly said to push, stop before step 6's push and ask. If the user only asked to commit, stop after step 4. The rules behind each step are in `docs/collaboration.md` §2.

## 1. Choose what to stage

- Run `git status --short` to see what changed.
- Stage **only the files you changed during this task (this conversation)**. Never `git add -A` or `git add .`.
- The working tree usually contains changes from the user or other agents. Unless the task is about them, **do not stage**:
  - `Packages/`, font assets, `Assets/ThirdParty/`
  - `.claude/`, temporary captures, scratch files, verification GIFs
- If you are unsure whether you changed a file, list it and ask. If a file you changed also contains someone else's edits (check with `git diff`), ask.
- For every new `.cs` file, stage its `.meta` too.

## 2. Docs

Update the `docs/` pages related to this task to the current state and stage them too (`docs/ARCHITECTURE_MAP.md` when the structure changed).

## 3. Tests (when Core changed)

If anything under `Assets/Scripts/Core/` changed, run the EditMode tests. Otherwise just confirm there are no compile errors.

Before running tests:
- Make sure the Editor is not in Play Mode. If it is, it may be someone else's session — wait or ask; do not stop it.
- If a Prefab Mode stage is open, back up the prefab file and close the stage first.

If any test fails, **do not commit**. Show the failures and stop.

## 4. Commit

- **If there is no `develop` branch** (neither local nor `origin/develop`), tell the user and offer to create it locally from `main`. Creating it on the remote happens only with the push approval in step 6.
- Commit on a `feat/<short-name>` branch. If you are on `develop` or `main`, create the branch from `develop` first (switching keeps your uncommitted changes).
- Message: title `feat|fix|refactor|docs|chore|test(scope): …` describing what changed and how (reason or condition in parentheses). Body: `- ` lines with what changed and numbers (before → after), and how it was verified. End with any attribution trailer your environment requires.
- Never skip hooks (`--no-verify`).

## 5. Sync develop

Sync **after** committing, and without touching the working tree. Before the commit, your task's changes and other people's work in progress are still uncommitted, and `git pull --rebase` refuses to run (`cannot pull with rebase: You have unstaged changes`).

- Check for a remote with `git remote`. **If there is no `origin`**, skip this step and the push in step 6; say so in the report.
- `git fetch origin`, then compare: `git rev-list --left-right --count develop...origin/develop` prints `<only local> <only remote>`.
  - `0 0` or `N 0` — nothing to bring in.
  - `0 N` (behind only) — from your task branch, run `git fetch origin develop:develop`. It fast-forwards local `develop` without checking it out, so the working tree is untouched.
  - `N M` (both sides have commits, e.g. an earlier merge is still waiting for push approval) — **stop and ask**. Show `git log --oneline --graph develop...origin/develop`. Do not rebase `develop`: that would flatten the earlier merge commit. With the user's OK, step 6 merges `origin/develop` into `develop` before merging the task branch.
- On conflicts, do not resolve them on your own — show them and ask.

## 6. Merge into develop and push

```bash
git checkout develop
# only if step 5 found both sides had commits and the user said OK:
git merge origin/develop
git merge feat/<name>
git branch -d feat/<name>
# only with the user's push approval and an origin remote:
git push origin develop
```

- Before pushing, confirm with the user unless their request already said "push". Show what will be pushed (`git log --oneline origin/develop..develop`).
- On merge conflicts, do not resolve them alone: show the files and both sides, and mention that `git merge --abort` returns to the previous state.
- Do not push the task branch. Do not touch `main`.
- If `git checkout` is blocked by someone else's changes, do not stash them away — show which files and ask.
- If `git branch -d` refuses, do not force it with `-D`; find out why.

## 7. Report

Briefly:
- Commit hash and title, number of files committed
- Branch merged, and whether develop was pushed (pushed / awaiting approval / no remote)
- Test results (pass count if run, or why not run)
- **Changes intentionally left unstaged**
