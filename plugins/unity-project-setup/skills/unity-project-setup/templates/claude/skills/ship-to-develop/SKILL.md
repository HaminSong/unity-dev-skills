---
name: ship-to-develop
description: Commits the current task, merges it into develop and pushes develop, staging only the files this task changed. Use when the user says "commit", "merge into develop", "push", "ship it" or similar in this repository.
---

# ship-to-develop — sync → commit → merge into develop → push

The user asking for this is the approval to commit, merge and push. Follow the steps in order and stop to ask only where a step says so. The rules behind each step are in `docs/collaboration.md` §2.

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

- `git fetch origin`. If `develop` is behind `origin/develop`, update first (`git pull --rebase origin develop` if you have unpushed commits).
- On conflicts, do not resolve them on your own — show them and ask.

## 5. Commit

- If the current branch is `develop`, create `feat/<short-name>` and commit there.
- Message: title `feat|fix|refactor|docs|chore|test(scope): …` describing what changed and how (reason or condition in parentheses). Body: `- ` lines with what changed and numbers (before → after), and how it was verified. End with any attribution trailer your environment requires.
- Never skip hooks (`--no-verify`).

## 6. Merge into develop and push

```bash
git checkout develop
git merge feat/<name>
git push origin develop
git branch -d feat/<name>
```

- On merge conflicts, do not resolve them alone: show the files and both sides, and mention that `git merge --abort` returns to the previous state.
- Do not push the task branch. Do not touch `main`.
- If `git checkout` is blocked by someone else's changes, do not stash them away — show which files and ask.
- If `git branch -d` refuses, do not force it with `-D`; find out why.

## 7. Report

Briefly:
- Commit hash and title, number of files committed
- Branch merged and push result
- Test results (pass count if run, or why not run)
- **Changes intentionally left unstaged**
