# unity-dev-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](https://github.com/HaminSong/unity-dev-skills/releases)
[![Unity 6](https://img.shields.io/badge/Unity-6-black.svg?logo=unity)](https://unity.com)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-D97757.svg)](https://docs.claude.com/en/docs/claude-code/plugins)

Claude Code skills for building Unity games with AI coding agents.

| Plugin | What it does |
|---|---|
| [unity-project-setup](plugins/unity-project-setup/skills/unity-project-setup/SKILL.md) | Prepares a new Unity project so AI agents can build most of it: layered architecture, project settings and a written operating agreement, in one pass |

## unity-project-setup

**The groundwork and ground rules for handing a Unity project to AI agents.**

Agents do good work when the repository tells them where code goes, what they must not touch, how to check their own work and how to hand off to the next session. They do poor work when those answers live only in someone's head. This skill writes those answers into the project on day one, as real files: folders and assemblies that the compiler enforces, settings applied through the Editor, and a `docs/` set that agents read first and keep current.

The rules were not designed up front. Each one was added after a real incident on a shipped mobile game, built by one developer with several AI agents sharing the same repository and Unity Editor. The skill's [`why-these-rules.md`](plugins/unity-project-setup/skills/unity-project-setup/references/why-these-rules.md) records the incident behind each rule.

Ask Claude something like:

- *"Set up this Unity project — folders, assemblies, coding rules."*
- *"I just created an empty Unity project at `D:\Dev\Orbit`. Scaffold it with prefix `Orbit`, landscape."*
- *"Get this project ready for AI agents to work on in parallel."*

Claude asks a handful of questions (prefix, names, orientation, optional layers), shows a dry run, then creates:

```
Assets/
  Art/ Audio/ Data/ Materials/ Prefabs/ Resources/ Scenes/ Settings/ Shaders/ ThirdParty/
  Scripts/
    Core/            Game.Core        pure C# (noEngineReferences): rules, contracts, events
      Tests/EditMode Game.Core.Tests  EventBus tests (8)
    Data/            Game.Data        ScriptableObject tuning and content
    Gameplay/        Game.Gameplay    physics, input, world, camera, audio
    UI/              Game.UI          HUD and screens — never references Gameplay
    Persistence/     Game.Persistence save I/O
    Bootstrap/       Game.Bootstrap   composition root (no singletons)
    Editor/          Game.Editor      Tools > Project Setup > Apply Defaults
docs/                index, architecture map, design + SOLID, coding rules, collaboration, task brief template
.claude/skills/ship-to-develop/       sync → commit → merge to develop → push
AGENTS.md  CLAUDE.md  .editorconfig  .gitattributes  .gitignore
```

Highlights:

- **Enforced layering.** asmdef references follow one direction; Core cannot see UnityEngine, and UI and Gameplay cannot see each other. Contracts live in Core, wiring in a single composition root.
- **Settings applied the safe way.** Force Text, Visible Meta Files, Linear, orientation, Input System only, and Enter Play Mode with Domain Reload off are applied by an Editor menu through the Editor API — not by copying `ProjectSettings/*.asset`, which breaks across Unity versions.
- **Git ready.** Unity `.gitattributes` with LFS and UnityYAMLMerge, Unity `.gitignore`, a `main`/`develop` branch model.
- **Rules agents actually follow.** `AGENTS.md` (imported by `CLAUDE.md`) points every agent to concise docs: file-size limits, event rules, runtime-uGUI traps, how to share one Unity Editor between several agents, and what to never stage.
- **Starter code with tests.** A typed, re-entrancy-safe `EventBus` with 8 EditMode tests and a composition-root skeleton.
- **Never destructive.** Existing files are skipped and reported; `.meta` files are left to Unity; nothing is committed or pushed without confirmation.

### How it lets agents work on their own

Each piece the skill lays down answers a question an agent would otherwise have to guess at or ask about:

| What an agent needs | What provides it |
|---|---|
| Where to start | `AGENTS.md` (imported by `CLAUDE.md`) points to the `docs/` index; agents open only the documents a task needs |
| Where code goes | One folder = one layer assembly. Wrong-direction references fail to compile, so mistakes show up as compiler errors instead of review comments |
| How to check its own work | Core is pure C#, so EditMode tests run headless. The rules require tests for every Core change, and "not verified" must be said out loud |
| How to hand off between sessions | The docs are the handoff: before finishing, agents update the docs to the current state instead of writing separate notes |
| How to work in parallel | A task brief template, one worktree per sub-task, a list of main-only files (scenes, composition root) and a file-overlap check before starting |
| How to share one Unity Editor | Check Play state first, stop your own Play session, close Prefab Mode before tests, never call `AssetDatabase.SaveAssets()` |
| How to commit safely | `ship-to-develop`: stage only your own files, sync first, test before committing, never force |
| When to grow the structure | File-size limits and written growth triggers, so agents neither over-engineer nor let files bloat |

The documents live outside `Assets/`, so Unity never imports them:

```
docs/
  README.md               index, plus one line per design or research document (date, summary, status)
  ARCHITECTURE_MAP.md     what the code looks like today: classes per layer, flows
  architecture-design.md  why the layers are split this way, and when to grow the structure
  coding-guidelines.md    coding rules, file-size limits, Unity pitfalls
  collaboration.md        branches, commits, parallel work, sharing the Editor
  tasks/TEMPLATE.md       brief for handing a task to another agent
```

They start as templates. Claude fills in only what it knows (a one-line game description, current contents), and the rules keep the docs current from then on:
- `AGENTS.md` requires updating related docs before finishing a task.
- `ship-to-develop` updates the docs and commits them together with the code.
- `ARCHITECTURE_MAP.md` must change whenever a class is added or moved.

**What it does not do:** make agents autonomous by itself. A person still decides what to build, reviews the work and releases to `main`. The skill makes the work between those decisions something agents can carry out reliably.

### Before you use it

The skill is built for a **new or nearly empty** project. It changes how your code compiles and how the Editor behaves, so read this first:

- **It always creates the full folder tree and one asmdef per layer.** All 10 `Assets/` folders and every layer assembly are created even if empty (only `Data`, `UI` and `Persistence` can be left out with `-Skip`). Unity writes a `.meta` for each folder, so empty folders end up in git. Delete the ones you don't want afterwards.
- **Assembly definitions change what can see what.**
  - Scripts left outside `Assets/Scripts/<Layer>/` still compile into `Assembly-CSharp`, and layer assemblies **cannot reference `Assembly-CSharp`** (or `Assembly-CSharp-firstpass` from `Plugins/`). Third-party assets without their own asmdef are invisible to your layered code until you give them one.
  - If a folder such as `Assets/Scripts/UI` already contains scripts, the new asmdef pulls them into that layer and they may stop compiling. For existing projects, follow "Adopting in an existing project" in [`setup-decisions.md`](plugins/unity-project-setup/skills/unity-project-setup/references/setup-decisions.md) instead of running the scaffold blindly.
  - An empty layer produces no DLL until it contains a script. That is normal Unity behaviour.
- **Apply Defaults changes Editor behaviour project-wide.**
  - **Input System only** — any code or asset that uses legacy `UnityEngine.Input` or `StandaloneInputModule` throws at runtime. Needs an Editor restart.
  - **Linear color space** — existing art and UI colors will look different than in Gamma.
  - **Domain Reload off** — static fields keep their values between Play sessions. Your code must reset mutable statics (the generated rules show how), and some third-party assets assume Domain Reload is on. Turn it back on in Project Settings > Editor if that bites.
- **Git conventions are opinionated.** `.gitattributes` routes binaries through **Git LFS**, so every collaborator needs Git LFS and your host's LFS quota applies. The docs and the `ship-to-develop` skill assume a `main` + `develop` flow with `feat/` branches; replace them if your team works differently.
- **It never overwrites or deletes.** Existing files are skipped and reported, and Claude shows a dry run first. Settings changes are applied only when the Apply Defaults menu runs, and nothing is committed or pushed without your confirmation.

It complements Unity's official [`unity:new-unity-project`](https://github.com/Unity-Technologies/unity-agent-plugin) skill: that one creates the project and installs packages, this one puts structure and rules on top.

### Requirements

- Unity 6 project with the **Input System** and **Test Framework** packages (the scaffold warns if they are missing)
- Windows PowerShell 5.1+ to run `scaffold.ps1` (PowerShell 7 on macOS/Linux should work but has not been tested)
- Optional: Git and Git LFS; [`unity-cli`](https://github.com/Unity-Technologies/unity-agent-plugin) so Claude can refresh the Editor, invoke the menu and run tests itself

## Installation

### As a Claude Code plugin (recommended)

```
/plugin marketplace add HaminSong/unity-dev-skills
/plugin install unity-project-setup@unity-dev-skills
```

### As a personal skill

Copy `plugins/unity-project-setup/skills/unity-project-setup/` into `~/.claude/skills/`. If you also install the plugin, remove the copy so the skill is not listed twice.

### On claude.ai

Zip `plugins/unity-project-setup/skills/unity-project-setup/` and upload it under Settings > Capabilities > Skills. The scaffold script needs a local PowerShell, so the full flow runs only in Claude Code on your machine.

## Customizing the conventions

The rules are deliberately opinionated — a consistent set beats a perfect one. To adopt your own:

1. Fork the repository.
2. Edit the source text in `skills/unity-project-setup/templates/` (`docs/` holds the rules themselves).
3. When changing layers, keep the layer table in `scripts/scaffold.ps1` and §2 of `templates/docs/architecture-design.md` in sync.
4. Bump `version` in both `plugin.json` and `marketplace.json`.

## Repository layout

```
.claude-plugin/marketplace.json          marketplace listing
plugins/unity-project-setup/
  .claude-plugin/plugin.json             plugin metadata and version
  skills/unity-project-setup/
    SKILL.md                             workflow and judgment calls (what to ask, what to default)
    scripts/scaffold.ps1                 folders, asmdefs, template copies (skips existing files)
    templates/                           source of every file written into the project
    references/                          layer decisions, adoption path, why each rule exists
```

## Verification status (0.1.0)

- `scaffold.ps1` (Windows PowerShell 5.1): fresh run, re-run (everything skipped), layer removal, URP off, missing-package warnings, invalid prefix/layer/orientation, non-Unity folder.
- Generated Core, Core.Tests, Bootstrap and Editor code compiles against Unity 6000.3.28f1 assemblies; the 8 EventBus tests pass outside the Editor.
- End-to-end in Unity 6000.3.28f1 (batch mode, fresh project with Input System 1.20.1, Test Framework 1.6.0, uGUI 2.0.0):
  - all generated code compiles; scripts placed in a layer folder compile into that layer's assembly (none fall into `Assembly-CSharp`)
  - **Tools > Project Setup > Apply Defaults** runs and every setting is saved to `ProjectSettings/`
  - the 8 EditMode tests pass through the Unity Test Runner
  - forbidden references fail to compile: Core → UnityEngine (`CS0246`) and UI → Gameplay (`CS0234`)
- **Not yet verified:** running `scaffold.ps1` under PowerShell 7 on macOS/Linux; adopting the structure in an existing project with many scripts.

## License

[MIT](LICENSE). The bundled `.gitignore` template is derived from [github/gitignore](https://github.com/github/gitignore) (CC0-1.0) and the `.gitattributes` template from [gitattributes/gitattributes](https://github.com/gitattributes/gitattributes) (MIT); their attribution headers are kept in the files.
