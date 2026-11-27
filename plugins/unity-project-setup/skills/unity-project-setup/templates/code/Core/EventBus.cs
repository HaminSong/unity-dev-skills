using System;
using System.Collections.Generic;
using {{PREFIX}}.Core.Events;

namespace {{PREFIX}}.Core
{
    /// <summary>
    /// Default IEventBus implementation. Pure C#, so EditMode tests can simply new it up.
    /// The composition root (GameBootstrapper) creates one instance and injects it. It is not a global singleton.
    /// </summary>
    /// <remarks>
    /// Publish does not allocate: it walks the handler list in place. Unsubscribing during a publish blanks the entry and the
    /// list is compacted after the outermost publish returns. Subscriptions added during a publish are not called until the next one.
    /// </remarks>
    public sealed class EventBus : IEventBus
    {
        private readonly Dictionary<Type, HandlerList> _handlers = new();

        /// <inheritdoc />
        public void Publish<T>(T evt) where T : IGameEvent
        {
            if (!_handlers.TryGetValue(typeof(T), out var list))
                return;

            var entries = list.Entries;
            var count = entries.Count; // fixed up front: handlers subscribed during this publish wait for the next one
            list.PublishDepth++;
            try
            {
                for (var i = 0; i < count; i++)
                {
                    var handler = entries[i].Handler; // null once disposed, even mid-publish
                    if (handler != null)
                        ((Action<T>)handler).Invoke(evt);
                }
            }
            finally
            {
                list.PublishDepth--;
                if (list.PublishDepth == 0 && list.HasRemovedEntries)
                    list.Compact();
            }
        }

        /// <inheritdoc />
        public IDisposable Subscribe<T>(Action<T> handler) where T : IGameEvent
        {
            if (handler == null)
                throw new ArgumentNullException(nameof(handler));

            if (!_handlers.TryGetValue(typeof(T), out var list))
            {
                list = new HandlerList();
                _handlers[typeof(T)] = list;
            }

            var entry = new Entry(handler);
            list.Entries.Add(entry);
            return new Subscription(list, entry);
        }

        /// <summary>One subscription's slot. Removal is by this object's identity, so subscribing the same delegate twice stays two independent entries.</summary>
        private sealed class Entry
        {
            public Delegate Handler;

            public Entry(Delegate handler) => Handler = handler;
        }

        /// <summary>Handlers for one event type, plus the bookkeeping that lets Publish iterate without copying.</summary>
        private sealed class HandlerList
        {
            public readonly List<Entry> Entries = new();
            public int PublishDepth;
            public bool HasRemovedEntries;

            public void Remove(Entry entry)
            {
                if (entry.Handler == null)
                    return;

                entry.Handler = null;
                if (PublishDepth > 0)
                    HasRemovedEntries = true; // compacted when the outermost publish ends
                else
                    Entries.Remove(entry);
            }

            public void Compact()
            {
                Entries.RemoveAll(e => e.Handler == null);
                HasRemovedEntries = false;
            }
        }

        /// <summary>Handle returned by Subscribe. Unsubscribes once on Dispose; further Dispose calls are ignored.</summary>
        private sealed class Subscription : IDisposable
        {
            private HandlerList _list;
            private Entry _entry;

            public Subscription(HandlerList list, Entry entry)
            {
                _list = list;
                _entry = entry;
            }

            public void Dispose()
            {
                _list?.Remove(_entry);
                _list = null;
                _entry = null;
            }
        }
    }
}
