module network_manager;
import blob;
import data : PlayerID;
import util.hash;
import allocation : IAllocator;

struct NetworkWrapper(T)
{
	TypeHash type;
	PlayerID id;
	size_t size;
	T data; 
}

struct NetworkEvent
{
	TypeHash type;
	PlayerID id;
	void[] data;
}

struct NetworkQueue
{
	Blob data;	

	this(IAllocator a) { data = Blob(a); } 
	void send(T)(PlayerID p, auto ref T t)
	{
		import log;
		logInfo("Sending output event: ", t, " to player ", p);
		auto n = NetworkWrapper!(T)(typeHash!T, p, Serializer.size(t), t);
		Serializer.serialize(n, data);
	}

	bool canReceive() { return data.hasData(); }

	bool isEventType(T)()
	{ 		
		auto b		   = data; //save yay.
		NetworkEvent e = Serializer.deserialize!NetworkEvent(b);
		return typeHash!(T) == e.type;
	}

	void receive(Funcs...)(Funcs f)
	{
		import std.traits;

		NetworkEvent e = Serializer.deserialize!NetworkEvent(data);
		foreach(i, func; f[0 .. $ - 1])
		{
			alias Params = Parameters!(Funcs[i]);
			alias T      = Params[1];
			if(typeHash!(T) == e.type)
			{
				Blob b = Blob(e.data);
				func(e.id, Serializer.deserialize!T(b));
				return;
			}	
		}

		f[$ -1](e);
	}

}

struct NetworkEventManager
{
	NetworkQueue outgoing;
	NetworkQueue incomming;
	this(IAllocator a)
	{
		this.outgoing  = NetworkQueue(a);
		this.incomming = NetworkQueue(a);
	}
}