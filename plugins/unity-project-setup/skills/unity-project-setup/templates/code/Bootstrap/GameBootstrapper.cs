using {{PREFIX}}.Core;
using {{PREFIX}}.Core.Events;
using UnityEngine;

namespace {{PREFIX}}.Bootstrap
{
    /// <summary>
    /// Composition root. The only place that creates services (EventBus, ...) once and wires them into runtime objects.
    /// Other layers never look each other up (no FindObjectOfType, no singletons); they use only what they receive here.
    /// Attach one to an empty GameObject in the first scene. When it approaches 500 lines, split it into installers (docs/architecture-design.md section 4).
    /// </summary>
    /// <remarks>
    /// Unity does not guarantee Awake order between objects. DefaultExecutionOrder makes this Awake run before scripts with the
    /// default order (0), but other objects should still receive their dependencies through Init(...) from here rather than
    /// reaching for them in their own Awake.
    /// </remarks>
    [DefaultExecutionOrder(-1000)]
    public sealed class GameBootstrapper : MonoBehaviour
    {
        private IEventBus _eventBus;

        /// <summary>Creates and wires services. Runs early via DefaultExecutionOrder; wiring order here is dependency order.</summary>
        private void Awake()
        {
            _eventBus = new EventBus();

            // Create services → world (Gameplay) → screens (UI) here, in that order, and pass them in through Init(...).

            _eventBus.Publish(new GameBootedEvent());
        }
    }
}
