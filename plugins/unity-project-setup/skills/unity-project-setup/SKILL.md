---
name: unity-project-setup
description: Lays a layered architecture and team conventions onto a fresh Unity project in one pass — per-layer Assembly Definitions (engine-free Core, Data, Gameplay, UI, Persistence, Bootstrap, Editor, EditMode tests) with enforced dependency direction, a standard Assets folder tree, project settings applied through the Editor API (Force Text, Linear, Input System only, fast Enter Play Mode), Unity-aware .gitattributes/.gitignore with LFS, an .editorconfig naming policy, agent-ready docs (AGENTS.md, architecture map, coding and collaboration rules), a tested EventBus, and a commit workflow skill. Use it whenever the user has just created a Unity project, asks to set up folders, asmdefs or architecture, wants coding conventions, naming rules or git/branching rules for a Unity game, or wants to move a small existing project onto a clean layered structure — even if they never say "scaffold". Complements unity:new-unity-project, which creates the project and installs packages.
---

# Unity Project Setup

Gives a new Unity project a clean, layered structure and a complete set of working rules on day one.

Teams usually acquire these rules one incident at a time: a file grows to 2,000 lines, so a split rule appears; branch names drift three ways, so a naming rule appears; a test overwrites an open prefab, so a testing rule appears. By the time the rules exist they are scattered across chats and half-remembered docs. This skill lays down the whole set at once, as real files in the project, so humans and AI agents start from the same playbook. The rules come from a shipped mobile game built by one developer working alongside several AI agents; `references/why-these-rules.md` records the incident behind each one.

**What this skill produces:** folders, `.asmdef` files, starter C# code with tests, an Editor menu that applies project settings, git attributes and ignores, an `.editorconfig`, a `docs/` set, `AGENTS.md`/`CLAUDE.md`, and a project-local commit skill. It ends with a report of what was created and what still needs checking inside Unity.

**What it does not do:** create the Unity project, install packages, or touch `ProjectSettings/*.asset` files directly. Use `unity:new-unity-project` (or Unity Hub) first if the project does not exist yet.

## Workflow

Work through the steps in order. Steps 2 and 3 are deterministic and scripted; the judgment lives in steps 0, 1 and 5.

### Step 0 — Preflight

- Confirm `ProjectSettings/ProjectVersion.txt` exists at the target path. If it does not, this is not a Unity project yet: offer to create one with `unity:new-unity-project` or Unity Hub, then come back.
- If `Assets/Scripts` already contains code or `.asmdef` files, **do not scaffold over it**. The script never overwrites, but layering new assemblies over loose scripts can break compilation. Follow "Adopting in an existing project" in `references/setup-decisions.md` instead, and show the user the plan before moving anything.
- If the Unity Editor has this project open, new files trigger a recompile. That is fine, but if it is in Play Mode, wait until it stops — never edit scripts during Play.

### Step 1 — Ask once, with defaults

Ask only these, in a single round (use a multiple-choice question tool such as `AskUserQuestion` if available). If the user says "just use defaults", use the defaults without asking again.

| Setting | Default | Why it matters |
|---|---|---|
| Assembly / namespace prefix | `Game` | Becomes every asmdef name (`Game.Core`) and root namespace. Tedious to change later. PascalCase. |
| Product and company name | Folder name, `DefaultCompany` | Written to Player Settings. |
| Screen orientation | `Portrait` | `Landscape` for PC/console or landscape mobile; `AutoRotation` if both. |
| Layers to leave out | None | Only `Data`, `UI` and `Persistence` are optional. See `references/setup-decisions.md` before dropping any — when unsure, keep them. |
| Render pipeline | Whatever is installed | If URP is in the manifest, Gameplay, UI and Editor reference the URP runtime assemblies. |

### Step 2 — Scaffold with `scripts/scaffold.ps1`

The script does everything that must come out the same every time: folders, asmdefs with correct references, template copies and placeholder substitution. Always run a dry run first and show the user what will be written, then run it for real.

```powershell
powershell -ExecutionPolicy Bypass -File "<skill dir>/scripts/scaffold.ps1" `
  -ProjectPath "<project>" -Prefix Game -Product "My Game" -Company "DefaultCompany" `
  -Orientation Portrait -DryRun
```

Options:

- `-Skip "Persistence,UI"` drops optional layers. They are removed from other asmdefs' references and from the tables and diagram in the generated docs. Prose mentions are not rewritten — fix those in Step 5.
- `-Urp false` omits URP references even when URP is installed (default: auto-detect from `Packages/manifest.json`).
- Existing files are reported as `SKIP` and left untouched. `.meta` files are never written — Unity generates them.
- `WARN` lines mean a package is missing. Input System and Test Framework matter: the rules mandate Input System, and the test assembly will not compile without Test Framework. Offer to install them (via `unity:unity-package-management` if available) rather than editing `manifest.json` by hand.

What the script lays down:

| Location | Contents |
|---|---|
| `Assets/` | `Art`, `Audio`, `Data`, `Materials`, `Prefabs`, `Resources`, `Scenes`, `Settings`, `Shaders`, `ThirdParty` |
| `Assets/Scripts/<Layer>/` | One asmdef per layer; reference rules in `templates/docs/architecture-design.md` §2 |
| `Assets/Scripts/Core/` | `IEventBus`, `EventBus`, `IGameEvent` + `GameBootedEvent` |
| `Assets/Scripts/Core/Tests/EditMode/` | Test asmdef and `EventBusTests` (8 tests) |
| `Assets/Scripts/Bootstrap/` | `GameBootstrapper` composition root skeleton |
| `Assets/Scripts/Editor/ProjectSetup/` | `ApplyProjectSettings` (run in Step 3) |
| Project root | `.gitattributes`, `.gitignore`, `.editorconfig`, `AGENTS.md`, `CLAUDE.md` |
| `docs/` | `README.md` (index), `ARCHITECTURE_MAP.md`, `architecture-design.md`, `coding-guidelines.md`, `collaboration.md`, `tasks/TEMPLATE.md` |
| `.claude/skills/ship-to-develop/` | Project skill: sync → commit → merge to `develop` → push |

### Step 3 — Apply project settings inside Unity

Settings are applied through the Editor API rather than by copying `ProjectSettings/*.asset`. Those files change format between Unity versions; copying them from another project corrupts settings or is silently ignored.

1. Let Unity compile the new files (focus the Editor, or `unity-cli`'s `editor refresh`). Check the Console has zero errors.
2. Run **Tools > Project Setup > Apply Defaults** (with `unity-cli`: `editor invoke_menu "Tools/Project Setup/Apply Defaults"`). It is idempotent and sets:
   - Asset Serialization: Force Text; Version Control: Visible Meta Files
   - Color Space: Linear; product/company name; default orientation
   - Active Input Handling: Input System only
   - Enter Play Mode Options on, Domain Reload off, Scene Reload on. This pairs with the coding rule "reset mutable statics on Play" in `coding-guidelines.md` — the two only work together.
3. Switching Active Input Handling needs an **Editor restart**. Ask the user to restart; do not quit their Editor yourself.
4. Run the `<Prefix>.Core.Tests` EditMode tests and confirm all 8 pass. Close any open Prefab Mode stage first — a test run can write a stale copy over an open prefab.

If you cannot reach the Editor, list these four items under "still to do" in the report instead of claiming them.

### Step 4 — Git

- No repository yet: `git init -b main`, then create and switch to `develop`. If Git LFS is installed, run `git lfs install`.
- Make the first commit only after the user confirms: `chore: initial project setup (folders, assemblies, settings, docs, rules)`.
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
