# Setup decisions — layers, variants, existing projects

## When a layer can be left out

| Layer | Safe to drop when | What happens if dropped |
|---|---|---|
| Core | Never | Every other layer builds on it. Pure C# rules, contracts and events are what make EditMode testing possible. |
| Data | Very small games whose numbers all live as code constants | No ScriptableObject tuning; every balance change is a recompile. |
| Gameplay | Never | |
| UI | Prototypes with almost no UI (a one-line HUD) | UI code ends up in Gameplay. Split it out once the UI grows. |
| Persistence | Games with no saving at all | When saving arrives: `ISaveService` goes in Core, its implementation in a new Persistence layer. |
| Bootstrap | Never | Without a composition root, singletons creep in. |
| Editor | Never | `ApplyProjectSettings` lives here. |
| Core.Tests | Never | |

When in doubt, keep the layer. An empty asmdef costs almost nothing; splitting a layer out of an established codebase later costs a lot.

## Layers to add (only on request)

- **Gameplay.Tests (PlayMode)** — when physics or coroutines need automated tests. Not included by default; MonoBehaviours are verified by playing.
- **Net** — multiplayer. Implements Core contracts (`INetSession`, …) and sits at the same level as Gameplay. Gameplay talks to it through interfaces, never by direct reference.
- **Feature sub-assemblies** (`Game.Gameplay.Boss`) — only when compile times become a problem. Start with folders inside a layer; keep asmdefs at layer granularity.

## Variants by genre and form

- **2D** — URP's 2D Renderer uses the same assembly reference (`Unity.RenderPipelines.Universal.Runtime`). 2D physics stays inside Gameplay.
- **PC / console** — orientation `Landscape`; everything else is identical.
- **Throwaway prototype (a day or two)** — ask once whether to leave out the optional layers (`-Skip "Data,UI,Persistence"`), which keeps Core, Gameplay, Bootstrap, Editor and Core.Tests. If it might become a real project, scaffold everything.
- **Addressables / Localization** — when adopted, add the package's assembly reference only to the layers that need it (e.g. Localization in UI only). Do not pre-add them.

## Adopting in an existing project

For a project whose scripts already live in `Assembly-CSharp`:

1. **Map before moving.** Show a table assigning every script to a layer and get approval. Do not move files yet.
2. **One asmdef at a time, Core first.** An asmdef captures everything below its folder at once. Confirm zero compile errors after each one.
3. **Preserve GUIDs.** Move scripts inside the Unity Editor, or move each `.cs` together with its `.meta`. A changed GUID breaks every scene and prefab reference to that script (Missing Script).
4. **Break cycles with interfaces.** asmdef references cannot be bidirectional; when two layers need each other, lift the interface into Core.
5. **Docs and rule files can go in immediately** (`AGENTS.md`, `CLAUDE.md`, `docs/`, `.editorconfig`, `ship-to-develop`). If a file with the same name exists, ask whether to merge rather than skip silently.
