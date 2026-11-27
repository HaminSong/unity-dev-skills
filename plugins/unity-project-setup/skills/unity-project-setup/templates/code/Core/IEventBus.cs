using System;
using {{PREFIX}}.Core.Events;

namespace {{PREFIX}}.Core
{
    /// <summary>Event bus contract. Lets publishers and subscribers stay unaware of each other (DIP): the contract lives in Core, the instance is created by the composition root.</summary>
    public interface IEventBus
    {
        /// <summary>Publishes an event. Every subscribed handler runs immediately (synchronously), in subscription order.</summary>
        /// <remarks>
        /// Handlers run over a snapshot taken when Publish starts: subscribing or disposing during a publish is safe,
        /// but only takes effect from the next publish (a handler disposed mid-publish still receives the current event).
        /// An exception thrown by a handler propagates to the publisher and the remaining handlers are not called.
        /// </remarks>
        void Publish<T>(T evt) where T : IGameEvent;

        /// <summary>Subscribes to an event. Dispose the returned IDisposable to unsubscribe — MonoBehaviours must do so in OnDestroy.</summary>
        IDisposable Subscribe<T>(Action<T> handler) where T : IGameEvent;
    }
}
