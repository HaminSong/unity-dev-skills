# unity-dev-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-orange.svg)](https://github.com/HaminSong/unity-dev-skills/releases)
[![Unity 6](https://img.shields.io/badge/Unity-6-black.svg?logo=unity)](https://unity.com)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-D97757.svg)](https://docs.claude.com/en/docs/claude-code/plugins)

Claude Code skills for Unity game development.

| Plugin | What it does |
|---|---|
| [unity-project-setup](plugins/unity-project-setup/skills/unity-project-setup/SKILL.md) | Gives a new Unity project a layered architecture and a complete set of team rules in one pass |

## unity-project-setup

Most Unity projects acquire their structure and rules one incident at a time — after a 2,000-line controller, after a broken merge, after a test overwrites an open prefab — and end up with those rules scattered across chats and stale docs. This skill lays the whole set down on day one, as real files, so people and AI agents work from the same playbook. Every rule was added after a real incident on a shipped mobile game; the skill's [`why-these-rules.md`](plugins/unity-project-setup/skills/unity-project-setup/references/why-these-rules.md) records each one.

Ask Claude something like:

> Set up this Unity project — folders, assemblies, coding rules.
> I just created an empty Unity project at `D:\Dev\Orbit`. Scaffold it with prefix `Orbit`, landscape.
> Split this small project into assemblies and add commit rules.

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
- **Not yet verified:** running Apply Defaults inside a live Unity Editor; running `scaffold.ps1` under PowerShell 7 on macOS/Linux.

## License

[MIT](LICENSE). The bundled `.gitignore` template is derived from [github/gitignore](https://github.com/github/gitignore) (CC0-1.0) and the `.gitattributes` template from [gitattributes/gitattributes](https://github.com/gitattributes/gitattributes) (MIT); their attribution headers are kept in the files.
