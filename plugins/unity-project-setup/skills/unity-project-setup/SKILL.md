---
name: unity-project-setup
description: Prepares a new Unity project for development with AI coding agents — layered assembly definitions the compiler enforces, a standard folder tree, Editor-applied project settings, Unity git files, and an AGENTS.md plus docs/ set that agents read first and keep current. Use when the user has just created a Unity project and wants it set up, asks for a folder structure, asmdefs or architecture for a Unity game, or wants a Unity project made ready for AI agents. Not for general coding-style questions. Complements unity:new-unity-project, which creates the project.
---

# Unity Project Setup

Lays the groundwork and ground rules for handing a Unity project to AI agents.

Agents do good work when the repository tells them where code goes, what they must not touch, how to check their own work and how to hand off to the next session. They do poor work when those answers live only in someone's head. Teams usually learn the answers one incident at a time: a file grows to 2,000 lines, so a split rule appears; branch names drift three ways, so a naming rule appears; a test overwrites an open prefab, so a testing rule appears. By then the rules are scattered across chats and half-remembered docs. This skill writes the whole set into the project on day one: assemblies that the compiler enforces, settings applied through the Editor, and a `docs/` set that agents read first and keep current. The rules come from a mobile game in development, built by one developer with several AI agents; `references/why-these-rules.md` records the incident behind each one.

**What this skill produces:** folders, `.asmdef` files, starter C# code with tests, an Editor menu that applies project settings, git attributes and ignores, an `.editorconfig`, a `docs/` set, `AGENTS.md`/`CLAUDE.md`, and a project-local commit skill. It ends with a report of what was created and what still needs checking inside Unity.

**What it does not do:** create the Unity project, install packages, or touch `ProjectSettings/*.asset` files directly. Use `unity:new-unity-project` (or Unity Hub) first if the project does not exist yet.

## Workflow

Work through the steps in order. Steps 2 and 3 are deterministic and scripted; the judgment lives in steps 0, 1 and 5.

### Step 0 — Preflight

- Confirm `ProjectSettings/ProjectVersion.txt` exists at the target path. If it does not, this is not a Unity project yet: offer to create one with `unity:new-unity-project` or Unity Hub, then come back.
- If the project already has scripts, check whether any of the layer folders (`Assets/Scripts/Core`, `Data`, `Gameplay`, `UI`, `Persistence`, `Bootstrap`, `Editor`) already exist.
  - **None exist:** the scaffold is safe. New asmdefs only capture their own new folders. Existing scripts stay in `Assembly-CSharp`, and keep compiling there, because the layer assemblies are auto-referenced. Tell the user that existing code is not moved. Moving it is a separate, later step: "Adopting in an existing project" in `references/setup-decisions.md`.
  - **Any exists and holds code or an `.asmdef`:** do not scaffold over it. An asmdef would capture those scripts and can break compilation. Follow the adoption steps instead, and show the user the plan before moving anything.
- If the repository already has `.gitattributes` or `.gitignore`, the scaffold skips them. Offer to merge in the Unity entries (LFS, UnityYAMLMerge, `Library/`) rather than leaving them silently unchanged.
- If the project contains code without its own asmdef outside `Assets/Scripts` (Asset Store packages, `Plugins/`), warn that layer assemblies cannot reference `Assembly-CSharp` or `Assembly-CSharp-firstpass`. Code that needs those assets will only compile after they get an asmdef.
- If the Unity Editor has this project open, new files trigger a recompile. That is fine, but if it is in Play Mode, wait until it stops — never edit scripts during Play.

### Step 1 — Ask once, with defaults

Ask only these, in a single round (use a multiple-choice question tool such as `AskUserQuestion` if available). If the user says "just use defaults", use the defaults without asking again.

Along with the questions, tell the user in two or three lines what they are agreeing to:
- The full folder tree and one asmdef per layer are always created, even if empty.
- Apply Defaults switches to Input System only and Linear color space.
- `.gitattributes` routes binaries through Git LFS.

If one of these is a problem (legacy `UnityEngine.Input` code, art tuned for Gamma, no LFS), settle it now rather than after the scaffold. Either skip that piece or plan to edit it afterwards.

| Setting | Default | Why it matters |
|---|---|---|
| Assembly / namespace prefix | `Game` | Becomes every asmdef name (`Game.Core`) and root namespace. Tedious to change later. PascalCase. |
| Product and company name | Folder name, `DefaultCompany` | Written to Player Settings. |
| Screen orientation | `Portrait` | `Landscape` for PC/console or landscape mobile; `AutoRotation` if both. |
| Layers to leave out | None | Only `Data`, `UI` and `Persistence` are optional. See `references/setup-decisions.md` before dropping any — when unsure, keep them. |
| Render pipeline | Whatever is installed | If URP is in the manifest, Gameplay, UI and Editor reference the URP runtime assemblies. |
| Fast Enter Play Mode | Off (Unity default) | Opt-in with `-FastPlayMode`: Play starts almost instantly because Domain Reload is skipped, but static fields keep values between Play sessions. Offer it; never turn it on without a yes. |

### Step 2 — Scaffold with `scripts/scaffold.ps1`

The script does everything that must come out the same every time: folders, asmdefs with correct references, template copies and placeholder substitution. Always run a dry run first and show the user what will be written, then run it for real.

```powershell
# Windows (built-in PowerShell 5.1)
powershell -ExecutionPolicy Bypass -File "<skill dir>/scripts/scaffold.ps1" `
  -ProjectPath "<project>" -Prefix Game -Product "My Game" -Company "DefaultCompany" `
  -Orientation Portrait -DryRun
# macOS / Linux (PowerShell 7): same arguments
pwsh -File "<skill dir>/scripts/scaffold.ps1" -ProjectPath "<project>" -Prefix Game -DryRun
```

`-ExecutionPolicy Bypass` applies only to this one process; it lets the unsigned script run without changing the machine's policy. If neither `powershell` nor `pwsh` exists, tell the user PowerShell 7 is needed and stop rather than recreating the script's work by hand.

Options:

- `-Skip "Persistence,UI"` drops optional layers. They are removed from other asmdefs' references and from the tables and diagram in the generated docs. Prose mentions are not rewritten — fix those in Step 5.
- `-FastPlayMode` makes Apply Defaults turn Domain Reload off. Pass it only if the user said yes in Step 1.
- `-Urp false` omits URP references even when URP is installed (default: auto-detect from `Packages/manifest.json`).
- Existing files are reported as `SKIP` and left untouched. `.meta` files are never written — Unity generates them.
- `WARN` lines mean a package is missing. Input System and Test Framework matter: the rules mandate Input System, and the test assembly will not compile without Test Framework. Offer to install them (via `unity:unity-package-management` if available) rather than editing `manifest.json` by hand.

What the script lays down:

| Location | Contents |
|---|---|
| `Assets/` | `Art`, `Audio`, `Data`, `Materials`, `Prefabs`, `Scenes`, `Settings`, `Shaders`, `ThirdParty` (no `Resources/` — Unity discourages it; use direct references or Addressables) |
| `Assets/Scripts/<Layer>/` | One asmdef per layer; reference rules in `templates/docs/architecture-design.md` §2 |
| `Assets/Scripts/Core/` | `IEventBus`, `EventBus`, `IGameEvent` + `GameBootedEvent` |
| `Assets/Scripts/Core/Tests/EditMode/` | Test asmdef and `EventBusTests` (13 tests) |
| `Assets/Scripts/Bootstrap/` | `GameBootstrapper` composition root skeleton |
| `Assets/Scripts/Editor/ProjectSetup/` | `ApplyProjectSettings` (run in Step 3) |
| Project root | `.gitattributes`, `.gitignore`, `.editorconfig`, `AGENTS.md`, `CLAUDE.md` |
| `docs/` | `README.md` (index), `ARCHITECTURE_MAP.md`, `architecture-design.md`, `coding-guidelines.md`, `collaboration.md`, `workflow.md` (idea → proposal → decision → plan → change, where documents go), `tasks/TEMPLATE.md` |
| `.claude/skills/ship-to-develop/` | Project skill: sync → commit → merge to `develop` → push only with a separate OK |

### Step 3 — Apply project settings inside Unity

Settings are applied through the Editor API rather than by copying `ProjectSettings/*.asset`. Those files change format between Unity versions; copying them from another project corrupts settings or is silently ignored.

1. Let Unity compile the new files: focus the Editor, or press Ctrl+R / Cmd+R to refresh. Check the Console has zero errors; the new **Tools** menu appearing is a quick sign the Editor assembly compiled. The `unity` CLI can also recompile a running Editor, but only once the project has the Unity Pipeline package.
2. Run **Tools > Project Setup > Apply Defaults**. It is idempotent and sets:
   - Asset Serialization: Force Text; Version Control: Visible Meta Files
   - Color Space: Linear; product/company name; default orientation
   - Active Input Handling: Input System only
   - Only with `-FastPlayMode`: Enter Play Mode Options on, Domain Reload off, Scene Reload on. Without it, Enter Play Mode settings are left untouched. The coding rule "reset mutable statics on Play" in `coding-guidelines.md` applies either way, so the project can switch later without new bugs.
3. Switching Active Input Handling needs an **Editor restart**. Ask the user to restart; do not quit their Editor yourself.
4. Run the `<Prefix>.Core.Tests` EditMode tests and confirm all 13 pass. Close any open Prefab Mode stage first — a test run can write a stale copy over an open prefab.

If you cannot reach the Editor, list these four items under "still to do" in the report instead of claiming them.

### Step 4 — Git

- No repository yet: `git init -b main`. If Git LFS is installed, run `git lfs install --local` — the plain `git lfs install` edits the user's global git config, which this skill must not touch.
- Make the first commit only after the user confirms, **on `main`**: `chore: initial project setup (folders, assemblies, settings, docs, rules)`. Then create and switch to `develop` (`git switch -c develop`), so both branches exist and point at the setup commit.
- Optionally offer to configure the Unity smart-merge driver for this repository (`git config`, never `--global`), using the installed Editor's `UnityYAMLMerge` path. The exact commands are in the generated `docs/collaboration.md` §2a. Without it, `merge=unityyamlmerge` in `.gitattributes` silently falls back to a plain text merge.
- Add a remote or push only when the user gives you the remote.

### Step 5 — Fill in what only this project knows

Templates arrive with placeholders filled but project facts empty. Fill these briefly — and leave a section empty rather than invent content:

- `docs/README.md` — one line describing the game.
- `docs/ARCHITECTURE_MAP.md` — the "current contents" column (today: EventBus only).
- `docs/architecture-design.md` §4 "Growth triggers" — one or two triggers this game is likely to hit, if known.
- Any prose that still mentions a layer removed with `-Skip`.

### Step 6 — Report

Keep it short, in this order:

1. **Created** — folder count, asmdef list, docs; existing files that were skipped.
2. **Chosen values** — prefix, orientation, removed layers; mark which were defaults.
3. **Verified in Unity** vs. **not yet verified** — compile, Apply Defaults, restart, tests. Never mark something verified because the code looks right.
4. **Git** — committed or not, current branch.

## Reference files

Read these only when the situation calls for them.

- `references/setup-decisions.md` — whether to drop or add layers; differences for 2D, PC/console, multiplayer and throwaway prototypes; the step-by-step path for adopting this structure in an existing project.
- `references/why-these-rules.md` — the incident behind each rule. Read it when the user asks "why does this rule exist?" or wants to change one, so they change it knowing what it prevents.
- `templates/` — the source text of every file the scaffold writes. `templates/docs/` is the single source of truth for the rules themselves; this file deliberately does not restate them.

## Adapting the conventions

The rules are opinionated on purpose: a consistent set is worth more than a perfect one. Teams that want different conventions should fork and edit `templates/` — for example, replace the `develop`-based flow in `templates/docs/collaboration.md` and the `ship-to-develop` skill with trunk-based development, or relax the file-size limits in `coding-guidelines.md`. Keep `scaffold.ps1`'s layer table and `architecture-design.md` §2 in sync when changing layers.
