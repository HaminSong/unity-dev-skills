using System;
using NUnit.Framework;
using {{PREFIX}}.Core;
using {{PREFIX}}.Core.Events;
using UnityEngine.TestTools.Constraints;
using Is = UnityEngine.TestTools.Constraints.Is;

namespace {{PREFIX}}.Core.Tests
{
    /// <summary>Pins down the EventBus Publish/Subscribe/Dispose contract. Pure C#, so it runs without a scene.</summary>
    public class EventBusTests
    {
        private readonly struct ValueEvent : IGameEvent
        {
            public readonly int Value;
            public ValueEvent(int value) => Value = value;
        }

        private readonly struct OtherEvent : IGameEvent
        {
        }

        [Test]
        public void Publish_InvokesSubscribedHandler()
        {
            var bus = new EventBus();
            var received = 0;
            bus.Subscribe<ValueEvent>(e => received = e.Value);

            bus.Publish(new ValueEvent(10));

            Assert.AreEqual(10, received);
        }

        [Test]
        public void Publish_WithNoSubscribers_DoesNotThrow()
        {
            var bus = new EventBus();

            Assert.DoesNotThrow(() => bus.Publish(new GameBootedEvent()));
        }

        [Test]
        public void Publish_OnlyInvokesHandlersOfMatchingType()
        {
            var bus = new EventBus();
            var valueCalled = false;
            var otherCalled = false;
            bus.Subscribe<ValueEvent>(_ => valueCalled = true);
            bus.Subscribe<OtherEvent>(_ => otherCalled = true);

            bus.Publish(new ValueEvent(1));

            Assert.IsTrue(valueCalled);
            Assert.IsFalse(otherCalled);
        }

        [Test]
        public void Publish_InvokesHandlersInSubscriptionOrder()
        {
            var bus = new EventBus();
            var order = "";
            bus.Subscribe<OtherEvent>(_ => order += "A");
            bus.Subscribe<OtherEvent>(_ => order += "B");

            bus.Publish(new OtherEvent());

            Assert.AreEqual("AB", order);
        }

        [Test]
        public void Dispose_StopsReceivingEvents()
        {
            var bus = new EventBus();
            var count = 0;
            var subscription = bus.Subscribe<OtherEvent>(_ => count++);

            subscription.Dispose();
            bus.Publish(new OtherEvent());

            Assert.AreEqual(0, count);
        }

        [Test]
        public void Dispose_Twice_IsSafe()
        {
            var bus = new EventBus();
            var subscription = bus.Subscribe<OtherEvent>(_ => { });

            subscription.Dispose();

            Assert.DoesNotThrow(() => subscription.Dispose());
        }

        [Test]
        public void Dispose_InsideHandler_DoesNotBreakCurrentPublish()
        {
            var bus = new EventBus();
            var secondCalled = false;
            IDisposable first = null;
            first = bus.Subscribe<OtherEvent>(_ => first.Dispose());
            bus.Subscribe<OtherEvent>(_ => secondCalled = true);

            Assert.DoesNotThrow(() => bus.Publish(new OtherEvent()));
            Assert.IsTrue(secondCalled);
        }

        [Test]
        public void Subscribe_NullHandler_Throws()
        {
            var bus = new EventBus();

            Assert.Throws<ArgumentNullException>(() => bus.Subscribe<OtherEvent>(null));
        }

        [Test]
        public void Subscribe_DuringPublish_IsCalledFromNextPublish()
        {
            var bus = new EventBus();
            var lateCalls = 0;
            var subscribed = false;
            bus.Subscribe<OtherEvent>(_ =>
            {
                if (subscribed) return;
                subscribed = true;
                bus.Subscribe<OtherEvent>(__ => lateCalls++);
            });

            bus.Publish(new OtherEvent());
            Assert.AreEqual(0, lateCalls);

            bus.Publish(new OtherEvent());
            Assert.AreEqual(1, lateCalls);
        }

        [Test]
        public void Dispose_OtherSubscriptionDuringPublish_SkipsItImmediately()
        {
            var bus = new EventBus();
            var secondCalled = false;
            IDisposable second = null;
            bus.Subscribe<OtherEvent>(_ => second.Dispose());
            second = bus.Subscribe<OtherEvent>(_ => secondCalled = true);

            bus.Publish(new OtherEvent());

            Assert.IsFalse(secondCalled);
        }

        [Test]
        public void HandlerException_PropagatesAndSkipsRemainingHandlers()
        {
            var bus = new EventBus();
            var laterCalled = false;
            bus.Subscribe<OtherEvent>(_ => throw new InvalidOperationException("boom"));
            bus.Subscribe<OtherEvent>(_ => laterCalled = true);

            Assert.Throws<InvalidOperationException>(() => bus.Publish(new OtherEvent()));
            Assert.IsFalse(laterCalled);
        }

        [Test]
        public void Dispose_SecondOfDuplicateSubscriptions_KeepsTheFirstInPlace()
        {
            var bus = new EventBus();
            var order = "";
            Action<OtherEvent> a = _ => order += "A";
            bus.Subscribe(a);
            bus.Subscribe<OtherEvent>(_ => order += "B");
            var secondA = bus.Subscribe(a);

            secondA.Dispose();
            bus.Publish(new OtherEvent());

            Assert.AreEqual("AB", order);
        }

        [Test]
        public void Publish_DoesNotAllocate()
        {
            var bus = new EventBus();
            var sum = 0;
            bus.Subscribe<ValueEvent>(e => sum += e.Value);
            bus.Subscribe<ValueEvent>(e => sum -= e.Value);
            bus.Publish(new ValueEvent(1)); // warm up (first call may JIT or grow internals)

            Assert.That(() => bus.Publish(new ValueEvent(2)), Is.Not.AllocatingGCMemory());
        }
    }
}
