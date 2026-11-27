namespace {{PREFIX}}.Core.Events
{
    /// <summary>Marker interface implemented by every game event. EventBus routes subscribers by event type.</summary>
    /// <remarks>
    /// Event rules (docs/coding-guidelines.md section 1):
    /// - Events are readonly structs. Field-less signal events are fine.
    /// - A new signal gets a new event; do not squeeze it into a similar existing one.
    /// - When this file passes 400 lines, split it by area (GameEvents.Round.cs, ...).
    /// </remarks>
    public interface IGameEvent
    {
    }

    /// <summary>Published once by the composition root when boot has finished and the first screen can be shown (no fields).</summary>
    public readonly struct GameBootedEvent : IGameEvent
    {
    }
}
