module eventmanager;

import allocation : IAllocator;
import collections;
import util.hash;
import std.traits;
import std.array;
import data : RiskState;
import blob;

alias eventHandler = void function(Event, ref RiskState);
struct EventManager
{
	Blob	data;
	HashMap!(TypeHash, eventHandler) handlers;

	this(IAllocator allocator)
	{
		data    = Blob(allocator, 1024);
		handlers = HashMap!(TypeHash, eventHandler)(allocator, 10);
	}

	static void invoker(T)(Event e, ref RiskState s)
	{
		Blob b = Blob(e.rawData);
		T t = Serializer.deserialize!T(b);
		t.apply(s);
	}

	void register(T)()
	{
		handlers.add(typeHash!T, &invoker!T);
	}

	void enque(T)(auto ref T t)
	{
		if(!handlers.has(typeHash!T))
			register!T();

		size_t size = Serializer.size(t);
		auto e = EventT!(T)(typeHash!T, size, t);
		Serializer.serialize(e, data);
	}

	void consumeEvents(ref RiskState state)
	{
		while(data.hasData())
		{
			auto event   = Serializer.deserialize!Event(data);
			auto handler = handlers[event.type];
			handler(event, state); 
		}
	}
}

//Gives this structure:
// [ typehash | size | data | typehash | size | data ]
struct Event
{
	TypeHash type;
	void[]	 rawData;
}

struct EventT(T)
{
	TypeHash type;
	size_t   size;
	T		 data;
}