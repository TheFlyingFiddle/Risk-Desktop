module experimental.channel;
import allocation;
import experimental.binaryblob;
import experimental.serialization.simple;
import util.hash;

//Typed binary stream. 
struct Channel(Header, Size=uint)
{
	struct SizedHeader
	{
		Header	 header;
		TypeHash type;
		Size	 size;
	}

	BinaryBlob blob;
	this(IAllocator allocator, size_t cap = 1024)
	{
		blob = BinaryBlob(allocator, cap);
	}

	bool empty() { return blob.empty; }

	void send(T)(Header h, auto ref T t)
	{
		auto sh = SizedHeader(h, typeHash!T, cast(Size)size(t));
		serialize(sh, blob); 
		serialize(t, blob);
	}

	void peek(T)(ref Header h, ref T t)
	{
		auto b = blob;
		auto sh = deserialize!SizedHeader(b);
		assert(sh.type == typeHash!T);
		h = sh.header;
		t = deserialize!T(b);
	}

	void peek(ref Header h, ref TypeHash type, ref void[] data) 
	{
		auto b = blob;
		auto sh = deserialize!SizedHeader(b);
		h	    = sh.header;
		data    = b.take(sh.size);
		type    = sh.type;
	}


	void receive(Funcs...)(Funcs f)
	{
		static if(__traits(compiles, () => funcs(Header.init, TypeHash.init, (void[]).init)))
			enum End = f.length - 1;
		else 
			enum End = f.length;


		import std.traits;
		auto sh = deserialize!SizedHeader(blob);
		foreach(i, func; f[0 .. End])
		{
			alias Params = Parameters!(Funcs[i]);
			alias T      = Params[1];
			if(typeHash!(T) == sh.type)
			{
				func(sh.header, deserialize!T(blob));
				return;
			}	
		}
	
		static if(End == f.length)
			assert(false, "Got an unexpected message while receiving from channel!");
		else
			f[End](sh.header, sh.type, blob.take(sh.size));
	}
}