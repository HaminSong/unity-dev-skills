using System;
using {{PREFIX}}.Core.Events;

namespace {{PREFIX}}.Core
{
    /// <summary>Event bus contract. Lets publishers and subscribers stay unaware of each other (DIP): the contract lives in Core, the instance is created by the composition root.</summary>
    public interface IEventBus
    {
        /// <summary>Publishes an event. Every subscribed handler runs immediately (synchronously), in subscription order.</summary>
        /// <remarks>
        /// Subscribing or disposing from inside a handler is safe. A disposal takes effect immediately: a handler whose
        /// subscription is disposed earlier in the same publish is skipped. A subscription added during a publish is not called
        /// by that publish, but is called by any later one — including a publish of the same event type nested inside a
        /// handler, which sees the current list. An exception thrown by a handler propagates to the publisher and the remaining
        /// handlers for that publish are not called.
        /// </remarks>
        void Publish<T>(T evt) where T : IGameEvent;

        /// <summary>Subscribes to an event. Dispose the returned IDisposable to unsubscribe — MonoBehaviours must do so in OnDestroy.</summary>
        IDisposable Subscribe<T>(Action<T> handler) where T : IGameEvent;
    }
}
