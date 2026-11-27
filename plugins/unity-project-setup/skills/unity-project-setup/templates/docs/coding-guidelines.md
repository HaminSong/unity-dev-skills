# Coding guidelines

- **Created** {{DATE}}
- Only the rules you need while writing or reviewing code. Structure and its reasons are in [architecture-design.md](architecture-design.md); branches, commits and parallel work are in [collaboration.md](collaboration.md).

## 1. Structure

- **Connect loosely through the event bus.** `IEventBus.Subscribe<T>` / `Publish<T>` (T : `IGameEvent`). Events are `readonly struct`s.
- **A new signal gets a new event.** Squeezing it into a similar existing event makes that event's other subscribers fire at the wrong time.
- **Always unsubscribe.** Keep the `IDisposable` returned by `Subscribe` and `Dispose` it in `OnDestroy`.
- **Split interfaces into read and write.** `I*View` / `I*Reader` versus `I*Control` / `I*Writer`. One class may implement both, but callers see only the narrow one they need.
- **UI that is not placed in a scene is built at runtime through a `static X.Create(...)` factory.**
- **One home for every rule and formula.** Compute displayed values and applied effects with the same Core function (prevents "the shop shows X, the game applies Y").

## 2. Style

- An XML `<summary>` on every class, public method and public property, in the team's working language: intent, side effects and when it is called — briefly.
- Names: private fields `_camelCase`, static private `s_camelCase`, public properties and methods `PascalCase`, interfaces prefixed with `I`. `.editorconfig` enforces these.
- Namespaces match the assembly name (`{{PREFIX}}.Core`, `{{PREFIX}}.Gameplay` …). Subfolders become sub-namespaces.
- Mark tunable numbers with a `// Tune here` comment, and move them to a Data ScriptableObject where practical.
- Player-facing strings live in one place (a `UiText` class or a Localization table).
- Multi-line UI strings use `\n`, not literal line breaks in source. A real line break inside a regular interpolated string is a compile error.
- When you need a new state variant, first consider a single flag on the existing controller that branches at its entry point (it reuses the existing event wiring) before building a new state machine. When flags start conflicting, follow the growth triggers in architecture-design §4.

## 3. Unity pitfalls (mandatory)

- **New Input System only.** Never use legacy `UnityEngine.Input` or `StandaloneInputModule`.
- When creating uGUI at runtime:
  1. Clicks need an `EventSystem` with an `InputSystemUIInputModule`.
  2. `AddComponent<Button>()` does not set `targetGraphic` — assign it yourself.
  3. A `Button`'s ColorTint overwrites `Image.color` as soon as it is active — put background colors in the `ColorBlock`.
- **Values serialized in scenes and prefabs beat code defaults.** Changing a field initializer does not affect scenes that already saved the field.
- **Domain Reload is off.** Any mutable static field (state, not a cache) needs a reset method that runs when Play starts:
  ```csharp
  [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
  private static void ResetStatics() { s_instance = null; }
  ```
- **Never change ScriptableObject values from code during Play.** The change survives in the asset after Play stops. Experiment on an `Instantiate`d copy.
- When a value must be forced without side effects, do not call an event-raising wrapper (`Heal()`) every frame; use a silent assignment (`Refill()`).

## 4. File size

- **Past 400 lines,** look for a responsibility to split out — and split before adding the next feature to that file. Never exceed 700 lines.
- **Anything that multiplies gets one file per kind from the start:** one file per enemy behaviour, per boss pattern, per screen. Do not grow a single file by appending `case`s.
- Split in this order: ① pure calculations → Core (with tests) ② progress and flow → a plain C# `*Director` ③ presentation → event subscribers. `partial class` is a last resort (it splits the file, not the responsibility).
- **Do not move or rename scripts referenced by scenes or prefabs.** If you must, do it inside Unity, or move the `.cs` together with its `.meta` so the GUID survives.
- **When refactoring, keep event publish order and public signatures unchanged.** Subscribers depend on the order.

## 5. Tests

- Core (pure C#) is covered by EditMode tests. Adding a class or method to Core means adding tests for it.
- MonoBehaviours (Gameplay, UI) are verified by playing.
- Before running tests, make sure the Editor is not in Play Mode and no Prefab Mode stage is open (a test run can overwrite the open prefab with a stale copy).
- If you changed code somewhere Unity cannot run, say explicitly that compile and Play verification are still pending.
