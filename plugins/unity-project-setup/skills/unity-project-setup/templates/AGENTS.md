# Agents working in this repository

- **Before starting**, read `docs/README.md` (the docs index) and open only the documents the task needs. For code changes read `docs/coding-guidelines.md`; for git or parallel work read `docs/collaboration.md`.
- **Before finishing**, update the related docs to match the new state (`docs/ARCHITECTURE_MAP.md` when the structure changes). Do not write separate handoff notes — the docs are the handoff.
- **Leave alone** `Packages/`, fonts and third-party asset packs (`Assets/ThirdParty`) unless the task is about them. The user edits these often.
- **Layer rules**: `{{PREFIX}}.Core` never references UnityEngine. UI and Gameplay never reference each other. Details in `docs/architecture-design.md`.

## Unity Editor

- Before Play, tests or captures, check whether the Editor is in Play Mode or in use by another agent. Never edit scripts during Play.
- If you entered Play Mode, exit it yourself and confirm it stopped.
- Close any open Prefab Mode stage before running tests (a test run can overwrite the open prefab with a stale copy).
- Do not call `AssetDatabase.SaveAssets()` from editor tooling. Do not revert assets with git while Unity is open.
- Do not change ScriptableObject values from code during Play (test on a copy).

## Git

- Commit, merge and push only when the user asks, following `.claude/skills/ship-to-develop/SKILL.md` (any agent can follow it as a checklist). Pushing needs an explicit OK. Stage only the files changed by the current task.
