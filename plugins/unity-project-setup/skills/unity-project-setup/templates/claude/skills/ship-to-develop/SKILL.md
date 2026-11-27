---
name: ship-to-develop
description: Finishes a task in this repository by committing it on a feat/ branch, merging into develop and, with separate confirmation, pushing develop — staging only the files this task changed. Use when the user asks to ship, merge into develop or push this task, or types /ship-to-develop. A plain "commit" request is not enough to push.
---

# ship-to-develop — sync → commit → merge into develop → (confirm) push

Asking for this skill approves committing and merging into the local `develop`. **Pushing is a separate approval**: unless the user's request explicitly said to push, stop before step 6's push and ask. If the user only asked to commit, stop after step 5. The rules behind each step are in `docs/collaboration.md` §2.

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

## 4. Sync

- Check for a remote with `git remote`. **If there is no `origin`**, skip syncing here and skip the push in step 6; say so in the report.
- **If there is no `develop` branch** (neither local nor `origin/develop`), tell the user and offer to create it locally from `main`. Creating it on the remote happens only with the push approval in step 6.
- Otherwise `git fetch origin`. If local `develop` is behind `origin/develop`, update it before merging: `git checkout develop` then `git pull --rebase origin develop`, then return to your task branch.
- On conflicts, do not resolve them on your own — show them and ask.

## 5. Commit

- Commit on a `feat/<short-name>` branch. If you are on `develop` or `main`, create the branch from `develop` first.
- Message: title `feat|fix|refactor|docs|chore|test(scope): …` describing what changed and how (reason or condition in parentheses). Body: `- ` lines with what changed and numbers (before → after), and how it was verified. End with any attribution trailer your environment requires.
- Never skip hooks (`--no-verify`).

## 6. Merge into develop and push

```bash
git checkout develop
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
