# Collaboration — branches, commits, parallel work

- **Created** {{DATE}}
- Rules for people and agents (Claude, Codex and others) sharing one repository and one Unity Editor.

## 1. Branches

- The remote holds only `main` and `develop`. Day-to-day work happens on `develop`.
- One task = one branch: **`feat/<short-name>`** (fixes and docs too — the commit title says what kind of change it is).
- When done, merge into `develop`; the only branch ever pushed is `develop`, and only when the user says so. Task branches are not pushed and are deleted after merging. `main` is updated by the user, for releases.
- History-rewriting commands (force push, rebasing pushed commits, `reset --hard`) only when the user explicitly asks.

## 2. Commits

- **Sync `develop` after committing, before merging into it.** Before the commit, the tree holds uncommitted changes (yours and other people's work in progress) and `git pull --rebase` refuses to run. Commit on the task branch, `git fetch origin`, then: if `develop` is only behind, `git fetch origin develop:develop` fast-forwards it without touching the working tree; if both sides have new commits, stop and ask — never rebase `develop`, which would flatten merge commits.
- **Stage only the files changed by this task.** No `git add -A` or `git add .` — the working tree always contains someone else's work in progress.
- Never staged without explicit confirmation: `Packages/`, font assets, third-party asset packs (`Assets/ThirdParty`), verification GIFs and captures, `.claude/`.
- When you create a `.cs` file, also stage the `.meta` Unity generated for it.
- Message format:
  ```
  feat(scope): what changed and how, in one line (reason or condition in parentheses)

  - What changed, with numbers where relevant (before → after)
  - How it was verified (n EditMode tests passed / checked in Play / not yet verified)
  ```
  Types: `feat` feature · `fix` bug fix · `refactor` structure only, same behaviour · `docs` documentation · `chore` settings, assets, tooling · `test` tests only. Scope is optional (`lobby`, `ui`, `audio` …).
- If Core changed, EditMode tests must pass before committing. Never skip hooks (`--no-verify`).
- Update the related `docs/` to the current state and include them in the same commit.
- `.claude/skills/ship-to-develop/SKILL.md` performs exactly this sequence when the user asks to ship or merge a task. Pushing always needs the user's explicit OK. Agents that do not load Claude skills can follow the same file as a checklist.
- Pushing to the remote happens only when the user says so.

## 2a. Smart merge for scenes and prefabs (once per machine)

`.gitattributes` marks Unity YAML files (`*.unity`, `*.prefab`, `*.asset`, …) with `merge=unityyamlmerge`. Git only uses Unity's smart merge tool if each machine defines that driver; otherwise it silently falls back to a plain text merge. Point it at the installed Editor (adjust the version and path):

```bash
git config merge.unityyamlmerge.name "Unity SmartMerge (UnityYAMLMerge)"
git config merge.unityyamlmerge.driver "'C:/Program Files/Unity/Hub/Editor/<version>/Editor/Data/Tools/UnityYAMLMerge.exe' merge -h -p --force %O %B %A %A"
git config merge.unityyamlmerge.recursive binary
```

On macOS the tool is at `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/Tools/UnityYAMLMerge`. Smart merge reduces scene conflicts but does not remove them — scenes stay main-only (§3).

## 3. Parallel work (main + sub-agents)

For speed, hand off to other agents only work whose files **do not overlap** with the main stream.

- **Overlapping files: in sequence. No overlap: in parallel.** Before starting, list the files each task will touch and check for overlap.
- A sub-task works only in **its own worktree and branch**, never in the main folder (file conflicts, plus the open Editor recompiles on every change).
- A sub-task **does not run Unity** (the same project cannot be open twice, and a separate worktree rebuilds `Library/` from scratch). It verifies through code and EditMode tests; Play verification happens in the main session after merging.
- **Main-only files** — sub-tasks do not touch them beyond lines their brief explicitly allows:
  - Scenes (`*.unity`) — scene merge conflicts are practically unresolvable
  - The composition root (`GameBootstrapper`) and core controllers
  - Unity-generated data assets (`Assets/Data/*.asset`) — when a new asset is needed, write the Editor menu code that creates it; the main session runs it
  - Decision records (design and progress logs)
- Sub-tasks do not create `.meta` files (Unity does).
- Write each brief from [tasks/TEMPLATE.md](tasks/TEMPLATE.md) as `docs/tasks/NN-name.md` and **commit it** before starting the sub-task (worktrees start from committed state).

## 4. Sharing the Unity Editor

- Before Play, tests, captures or save backups, check who is using the Editor. If someone is, wait or ask.
- Never edit scripts during Play (saving compiles after Stop, but the Play state gets tangled).
- **If you entered Play Mode, you exit it** — and confirm it stopped. Never stop someone else's Play session.
- Do not call `AssetDatabase.SaveAssets()` from editor tooling (MCP and the like) — it also saves assets the user is editing.
- Do not revert assets (fonts, prefabs) with git while Unity is open; the open Editor writes them back.
