using System;
using System.Collections.Generic;
using {{PREFIX}}.Core.Events;

namespace {{PREFIX}}.Core
{
    /// <summary>
    /// Default IEventBus implementation. Pure C#, so EditMode tests can simply new it up.
    /// The composition root (GameBootstrapper) creates one instance and injects it. It is not a global singleton.
    /// </summary>
    public sealed class EventBus : IEventBus
    {
        private readonly Dictionary<Type, List<Delegate>> _handlers = new();

        /// <inheritdoc />
        public void Publish<T>(T evt) where T : IGameEvent
        {
            if (!_handlers.TryGetValue(typeof(T), out var list))
                return;

            // Iterate over a snapshot so handlers can safely Subscribe or Dispose during Publish.
            var snapshot = list.ToArray();
            foreach (var handler in snapshot)
            {
                ((Action<T>)handler).Invoke(evt);
            }
        }

        /// <inheritdoc />
        public IDisposable Subscribe<T>(Action<T> handler) where T : IGameEvent
        {
            if (handler == null)
                throw new ArgumentNullException(nameof(handler));

            if (!_handlers.TryGetValue(typeof(T), out var list))
            {
                list = new List<Delegate>();
                _handlers[typeof(T)] = list;
            }
            list.Add(handler);

            return new Subscription(() => list.Remove(handler));
        }

        /// <summary>Handle returned by Subscribe. Unsubscribes once on Dispose; further Dispose calls are ignored.</summary>
        private sealed class Subscription : IDisposable
        {
            private Action _onDispose;

            public Subscription(Action onDispose) => _onDispose = onDispose;

            public void Dispose()
            {
                _onDispose?.Invoke();
                _onDispose = null;
            }
        }
    }
}
