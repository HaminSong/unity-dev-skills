# {{PRODUCT}} — Architecture map

- **Created** {{DATE}}
- **Purpose** Shows how the code on `develop` is structured today and how a session flows. This is a structural map, not a progress log. Principles and reasons live in [architecture-design.md](architecture-design.md).
- When you add or move a class, update the tables here in the same change.

## 1. Glossary

- **EventBus** — Event bus that passes `IGameEvent` structs through `Publish<T>` / `Subscribe<T>`. Not a global singleton: the composition root creates one and injects it.
- **Composition root** — `GameBootstrapper`. The only place that creates services and runtime objects and wires them together.
- (Add game terms here as they appear: round, stage, wave …)

## 2. Current contents by layer

| Assembly | Current contents |
|---|---|
| `{{PREFIX}}.Core` | `IEventBus`, `EventBus`, `IGameEvent` (`GameEvents.cs`) |
| `{{PREFIX}}.Data` | (empty) |
| `{{PREFIX}}.Gameplay` | (empty) |
| `{{PREFIX}}.UI` | (empty) |
| `{{PREFIX}}.Persistence` | (empty) |
| `{{PREFIX}}.Bootstrap` | `GameBootstrapper` (creates the EventBus only) |
| `{{PREFIX}}.Editor` | `ApplyProjectSettings` (Tools > Project Setup > Apply Defaults) |
| `{{PREFIX}}.Core.Tests` | `EventBusTests` |

Reference direction follows the diagram in architecture-design §2. If the real graph diverges, draw it here.

## 3. Flow

(Add state and sequence diagrams here once the game flow exists)
