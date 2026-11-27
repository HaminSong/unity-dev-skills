# unity-dev-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](https://github.com/HaminSong/unity-dev-skills/releases)
[![Unity 6](https://img.shields.io/badge/Unity-6-black.svg?logo=unity)](https://unity.com)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-D97757.svg)](https://docs.claude.com/en/docs/claude-code/plugins)

Agent skills for building Unity games with AI coding agents. Built and tested with Claude Code; the skill format and generated files are not Claude-specific.

| Plugin | What it does |
|---|---|
| [unity-project-setup](plugins/unity-project-setup/skills/unity-project-setup/SKILL.md) | Prepares a new Unity project for development with AI coding agents: layered architecture, project settings and written ground rules, in one pass |

## unity-project-setup

**The groundwork and ground rules for handing a Unity project to AI agents.**

Agents do better work when the repository tells them where code goes, what they must not touch, how to check their own work and how to hand off to the next session. When those answers live only in someone's head, agents guess. This skill writes the answers into the project on day one, as real files: folders and assemblies that the compiler enforces, settings applied through the Editor, and a `docs/` set that agents read first and keep current.

The rules were not designed up front. Each was added after a real incident on a mobile game in development, built by one developer with several AI agents sharing the same repository and Unity Editor. [`why-these-rules.md`](plugins/unity-project-setup/skills/unity-project-setup/references/why-these-rules.md) records the incident behind each rule.

Ask your agent something like:

- *"Set up this Unity project — folders, assemblies, coding rules."*
- *"I just created an empty Unity project at `D:\Dev\Orbit`. Scaffold it with prefix `Orbit`, landscape."*
- *"Get this project ready for AI agents to work on in parallel."*

The agent asks a handful of questions (prefix, names, orientation, optional layers), shows a dry run, then creates:

```
Assets/
  Art/ Audio/ Data/ Materials/ Prefabs/ Scenes/ Settings/ Shaders/ ThirdParty/
  Scripts/
    Core/            Game.Core        pure C# (noEngineReferences): rules, contracts, events
      Tests/EditMode Game.Core.Tests  EventBus tests (13)
    Data/            Game.Data        ScriptableObject tuning and content
    Gameplay/        Game.Gameplay    physics, input, world, camera, audio
    UI/              Game.UI          HUD and screens — never references Gameplay
    Persistence/     Game.Persistence save I/O
    Bootstrap/       Game.Bootstrap   composition root (no singletons)
    Editor/          Game.Editor      Tools > Project Setup > Apply Defaults
docs/                index, architecture map, design + SOLID, coding rules, collaboration, workflow, task brief template
.claude/skills/ship-to-develop/       commit → merge to develop → push only after a separate OK
AGENTS.md  CLAUDE.md  .editorconfig  .gitattributes  .gitignore
```

It complements Unity's official [`unity:new-unity-project`](https://github.com/Unity-Technologies/unity-agent-plugin) skill: that one creates the project and installs packages, this one puts structure and rules on top.

## Installation

### Claude Code (plugin, recommended)

```
/plugin marketplace add HaminSong/unity-dev-skills
/plugin install unity-project-setup@unity-dev-skills
```

### Other agents (Codex and others that read `SKILL.md`)

The skill is a standard `SKILL.md` folder, so any agent that loads skills can use it:

- **Copy the folder:** put `plugins/unity-project-setup/skills/unity-project-setup/` into your agent's skills directory (for example `~/.codex/skills/` or `~/.agents/skills/`).
- **Codex plugin:** the repository also ships `.agents/plugins/marketplace.json` and `plugins/unity-project-setup/.codex-plugin/plugin.json`, the same layout Unity uses for its official plugin.

These routes follow the shared format but **have only been tested in Claude Code**. On other agents, the multiple-choice question step falls back to plain questions. The generated project works the same with any agent: it uses the cross-agent `AGENTS.md`, and the commit procedure in `.claude/skills/ship-to-develop/SKILL.md` doubles as a checklist that `AGENTS.md` points to.

### Personal skill or claude.ai

- **Personal skill:** copy the same folder into `~/.claude/skills/`. If you also install the plugin, remove the copy so the skill is not listed twice.
- **claude.ai:** zip the folder and upload it under Settings > Capabilities > Skills. The scaffold needs a local PowerShell, so the full flow runs only where the agent can execute commands on your machine.

### Requirements

- Unity 6 project with the **Input System** and **Test Framework** packages (the scaffold warns if they are missing)
- PowerShell to run `scaffold.ps1`: Windows PowerShell 5.1 (built in) is tested. PowerShell 7 (`pwsh`) on macOS/Linux is untested. The script runs with `-ExecutionPolicy Bypass` for that one process only and changes no machine policy.
- Optional: Git and Git LFS; [`unity-cli`](https://github.com/Unity-Technologies/unity-agent-plugin) so the agent can refresh the Editor, invoke the menu and run tests itself

## Before you use it

The skill is built for a **new or nearly empty** project. It changes how your code compiles and how the Editor behaves:

- **It always creates the full folder tree and one asmdef per layer.** All 9 `Assets/` folders and every layer assembly are created even if empty; only `Data`, `UI` and `Persistence` can be left out with `-Skip`. Unity writes a `.meta` for each folder, so empty folders end up in git. Delete the ones you don't want afterwards.
- **Assembly definitions change what can see what.**
  - Scripts left outside `Assets/Scripts/<Layer>/` still compile into `Assembly-CSharp`, and layer assemblies **cannot reference `Assembly-CSharp`** (or `Assembly-CSharp-firstpass` from `Plugins/`). Third-party assets without their own asmdef are invisible to your layered code until you give them one.
  - If a folder such as `Assets/Scripts/UI` already contains scripts, the new asmdef pulls them into that layer and they may stop compiling. For existing projects, follow "Adopting in an existing project" in [`setup-decisions.md`](plugins/unity-project-setup/skills/unity-project-setup/references/setup-decisions.md) instead of running the scaffold blindly.
  - An empty layer produces no DLL until it contains a script. That is normal Unity behaviour.
- **Apply Defaults changes Editor behaviour project-wide.**
  - **Input System only** — any code or asset that uses legacy `UnityEngine.Input` or `StandaloneInputModule` throws at runtime. Needs an Editor restart.
  - **Linear color space** — existing art and UI colors will look different than in Gamma.
  - **Fast Enter Play Mode is opt-in.** Domain Reload stays on (Unity's default) unless you choose fast Play Mode. If you do, static fields keep their values between Play sessions; the generated rules show how to reset them, and some third-party assets assume Domain Reload is on.
- **Git conventions are opinionated.**
  - `.gitattributes` routes binaries through **Git LFS**, so every collaborator needs Git LFS and your host's LFS quota applies. The skill runs `git lfs install --local`, which changes only this repository's config.
  - Scenes and prefabs are marked for Unity's smart merge (UnityYAMLMerge). Each machine must define the merge driver once, as described in the generated `docs/collaboration.md` §2a; until then git falls back to a plain text merge.
  - The docs and `ship-to-develop` assume a `main` + `develop` flow with `feat/` branches. `ship-to-develop` commits and merges locally and **pushes only after a separate OK**. Replace them if your team works differently.
- **It never overwrites or deletes.** Existing files are skipped and reported, and a dry run comes first. Settings change only when the Apply Defaults menu runs, and nothing is committed or pushed without your confirmation.

## How it lets agents work on their own

Each piece the skill lays down answers a question an agent would otherwise have to guess at or ask about:

| What an agent needs | What provides it |
|---|---|
| How an idea becomes a change | `docs/workflow.md`: proposal first, the user decides, then plan, implement, verify and update docs. Plans and research have fixed folders, names and status headers |
| Where to start | `AGENTS.md` (imported by `CLAUDE.md`) points to the `docs/` index; agents open only the documents a task needs |
| Where code goes | One folder = one layer assembly. Wrong-direction references fail to compile, so mistakes show up as compiler errors instead of review comments |
| How to check its own work | Core is pure C#, so EditMode tests run headless. The rules require tests for every Core change, and "not verified" must be said out loud |
| How to hand off between sessions | The docs are the handoff: before finishing, agents update the docs to the current state instead of writing separate notes |
| How to work in parallel | A task brief template, one worktree per sub-task, a list of main-only files (scenes, composition root) and a file-overlap check before starting |
| How to share one Unity Editor | Check Play state first, stop your own Play session, close Prefab Mode before tests, never call `AssetDatabase.SaveAssets()` |
| How to commit safely | `ship-to-develop`: stage only your own files, sync first, test before committing, push only with an explicit OK, never force |
| When to grow the structure | File-size limits and written growth triggers, so agents neither over-engineer nor let files bloat |

The documents live outside `Assets/`, so Unity never imports them:

```
docs/
  README.md               index, plus one line per design or research document (date, summary, status)
  ARCHITECTURE_MAP.md     what the code looks like today: classes per layer, flows
  architecture-design.md  why the layers are split this way, and when to grow the structure
  coding-guidelines.md    coding rules, file-size limits, Unity pitfalls
  collaboration.md        branches, commits, smart merge setup, parallel work, sharing the Editor
  workflow.md             idea → proposal → user decision → plan → change; where documents go; index rules
  tasks/TEMPLATE.md       brief for handing a task to another agent
  intent/  research/  archive/   created when first needed: dated plans, research folders, finished documents
```

`workflow.md` sets the rule at the center of handing work to agents: **a proposal never changes the game until the user decides.** Every plan and research document carries a status header (proposal → decided → in progress → applied, or rejected/superseded). The index stays one short line per document, grouped into Reference, Active and Recently applied.

They start as templates. The agent fills in only what it knows (a one-line game description, current contents), and the rules ask agents to keep the docs current from then on:
- `AGENTS.md` requires updating related docs before finishing a task.
- `ship-to-develop` updates the docs and commits them together with the code.
- `ARCHITECTURE_MAP.md` must change whenever a class is added or moved.

**What it does not do:** make agents autonomous by itself. A person still decides what to build, reviews the work and releases to `main`. The skill gives agents clear rules for the work between those decisions.

### Other details

- **Settings applied through the Editor API.** Force Text, Visible Meta Files, Linear, orientation, Input System only and, if chosen, fast Enter Play Mode are applied by an Editor menu. `ProjectSettings/*.asset` files are never copied, because their format changes between Unity versions.
- **Starter code with tests.** A synchronous, allocation-free `EventBus` (subscribing or disposing from a handler is safe; disposal takes effect immediately) with 13 EditMode tests, plus a composition-root skeleton.
- **`.editorconfig` naming rules** that match the coding guidelines (`_camelCase` fields, `s_` statics, `I` interfaces).

## Customizing the conventions

The rules are deliberately opinionated — a consistent set beats a perfect one. To adopt your own:

1. Fork the repository.
2. Edit the source text in `skills/unity-project-setup/templates/` (`docs/` holds the rules themselves).
3. When changing layers, keep the layer table in `scripts/scaffold.ps1` and §2 of `templates/docs/architecture-design.md` in sync.
4. Bump `version` in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## Repository layout

```
.claude-plugin/marketplace.json          Claude Code marketplace listing
.agents/plugins/marketplace.json         Codex marketplace listing
plugins/unity-project-setup/
  .claude-plugin/plugin.json             Claude Code plugin metadata and version
  .codex-plugin/plugin.json              Codex plugin metadata and version
  skills/unity-project-setup/
    SKILL.md                             workflow and judgment calls (what to ask, what to default)
    scripts/scaffold.ps1                 folders, asmdefs, template copies (skips existing files)
    templates/                           source of every file written into the project
    references/                          layer decisions, adoption path, why each rule exists
```

## Verification status (0.1.0)

- `scaffold.ps1` (Windows PowerShell 5.1): fresh run, re-run (everything skipped), layer removal, URP off, missing-package warnings, invalid prefix/layer/orientation, non-Unity folder.
- End-to-end in Unity 6000.3.28f1 (batch mode, fresh project with Input System 1.20.1, Test Framework 1.6.0, uGUI 2.0.0):
  - all generated code compiles; scripts placed in a layer folder compile into that layer's assembly (none fall into `Assembly-CSharp`)
  - **Tools > Project Setup > Apply Defaults** runs and every setting is saved to `ProjectSettings/`. Without `-FastPlayMode` the Enter Play Mode settings are left untouched; with it, Domain Reload is turned off
  - the 13 EditMode tests pass through the Unity Test Runner, including a no-GC-allocation check on Publish
  - forbidden references fail to compile: Core → UnityEngine (`CS0246`) and UI → Gameplay (`CS0234`)
- Git steps on the generated project:
  - `git init -b main`, first commit on `main`, then `develop` on the same commit
  - `git lfs install --local` leaves the global git config unchanged
  - `.gitignore` excludes `Library/`; images route through LFS
  - with the merge driver from `docs/collaboration.md` §2a configured, git invokes UnityYAMLMerge and combines edits to two different fields of a settings asset
  - the `ship-to-develop` git sequence with no remote: `feat/` commit → merge into `develop` → branch deleted, no push
- These checks were run by the author and are not yet automated in this repository.
- **Not yet verified:**
  - `scaffold.ps1` under PowerShell 7 on macOS/Linux
  - installing on agents other than Claude Code
  - `ship-to-develop` driven by an agent, including the push confirmation
  - adopting the structure in an existing project with many scripts

## License

[MIT](LICENSE). The bundled `.gitignore` template is derived from [github/gitignore](https://github.com/github/gitignore) (CC0-1.0) and the `.gitattributes` template from [gitattributes/gitattributes](https://github.com/gitattributes/gitattributes) (MIT); their attribution headers are kept in the files.
