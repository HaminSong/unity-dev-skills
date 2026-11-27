# Why these rules exist

Read this when the user asks why a rule exists or wants to change one. Every rule below was added after something actually went wrong on the project these conventions come from: a mobile arcade game in development, built by one developer working with several AI coding agents in the same repository and the same Unity Editor. Change a rule knowing what it prevents, or the same incident comes back.

## Structure

- **Core has `noEngineReferences`.** While rules and formulas lived inside MonoBehaviours they could not be tested. Moving upgrade effects, currency rounding and collision follow-up logic into Core took the EditMode suite from 95 to 286 tests, and removed a bug where the shop displayed one value and applied another (the formula existed in two places).
- **UI and Gameplay do not know each other.** UI sees only `IRoundView` / `IRoundControl`-style interfaces. The lobby screen was rebuilt from scratch several times without touching gameplay code.
- **A composition root instead of singletons.** `GameBootstrapper` creates and wires everything in one place, so initialization order is visible at a glance. The cost is that this class grows — hence the pre-written trigger "split into installers at about 500 lines".
- **Growth triggers are written down in advance.** Rules like "introduce explicit state objects when flags start conflicting" prevented both over-building up front and hesitating when the time came. In practice a single flag solved the lobby state, which was safer than the state-class rewrite that had been tempting.
- **New signals get new events.** Lobby entry was once piggy-backed on `RoundStartedEvent`; subscribers meant only for round start began firing in the lobby. A separate `LobbyEnteredEvent` fixed it.

## File size

- A refactor cut the main round controller from 366 lines to a 220-line target. With no ceiling to hold it there, it was back to 1,528 lines about a month later. A boss-pattern file reached 2,218 lines because every new pattern was appended to it.
- Hence "a line limit, plus one file per kind for anything that multiplies (enemy behaviours, boss patterns, screens)".

## Unity pitfalls

- **Serialized scene values beat code defaults.** Changing a field initializer had no visible effect, repeatedly, because the scene had already serialized the old value.
- **Three runtime-uGUI traps** — no `EventSystem` means no clicks; `AddComponent<Button>()` leaves `targetGraphic` empty; ColorTint overwrites `Image.color`. All three were hit for real.
- **Domain Reload off + reset statics.** Entering Play Mode became much faster, but static state left over from the previous session caused bugs such as the loading screen not appearing. Fast Play Mode is therefore opt-in (`-FastPlayMode`), while the "reset mutable statics on Play" rule ships either way, so a project can switch later without new bugs.
- **No script edits during Play, no tests with a prefab open, no `AssetDatabase.SaveAssets()` from tools** — respectively: Play state got tangled; a test run wrote a stale prefab over the open one; an agent's save overwrote a font atlas the user was editing.
- **Never modify ScriptableObject catalog values from code during Play.** Asset values persist in memory after Play stops, which skewed the user's next play session. Test on an `Instantiate`d copy.

## Git and collaboration

- **One branch prefix.** `feature/`, `feat/` and two agent-specific prefixes were all in use at different times. New projects use `feat/<short-name>` only.
- **Stage only this task's files.** The working tree always contains someone else's work in progress. A `git add -A` once committed a half-finished font import and package change.
- **Sync `develop` — after committing, without touching the working tree.** A commit pushed from a second machine blocked a push with a divergent history, so a sync step was added. Its first version synced before committing with `git pull --rebase`, which refuses to run while anyone's work in progress is uncommitted in the tree; it now commits first and fast-forwards `develop` with `git fetch origin develop:develop`.
- **Scenes and the composition root belong to the main session.** Scene merge conflicts are practically unresolvable, so parallel task briefs list files that must not be touched.
- **Preserve GUIDs when moving or renaming `.cs` files.** Otherwise: Missing Script on every scene that used it.
- **Keep event publish order during refactors.** Subscribers depended on the order (score → heal → wave cleared).
- **The Unity Editor is shared between agents.** Two agents running Play, captures and save backups in the same Editor ruined each other's results. Check who is using it before starting; whoever starts Play stops it.
