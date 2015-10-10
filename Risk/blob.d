module blob;
import allocation;
import util.traits;
import std.traits;
import std.array;

//Requirements
//1. I want to be able to grow the blob.
//2. I want to be able to have a queue blob.
//3. I want to be able to take elements out of the blob and use them as I please ensuring that they remain valid. 
//4. I want to be able to save the blob to memory via only copying the memory to disk. 

//Number 3 is a problem since the memory might not be avaliable if the blob has grown / been overwritten. 
//Solving it can only be done via memory copy, but that is not prefereable if the usecase is short memory 
//usage. And this sucks ass.. Pardon my french. I can only rely on the GC for this since I don't know the 
//memory usecase of the data... Or I can use smart pointers this will work. I must in this case allocate 
//manually if I want to use the memory. But that is ok. ignoring problem 3. 
struct Blob
{
	void[] store;
	size_t back, front;
	IAllocator allocator;

	this(IAllocator allocator, size_t cap = 1024)
	{
		this.allocator = allocator;
		this.back = this.front = 0;
		store     = allocator.allocateRaw(cap, 8);
	}

	this(void[] data)
	{
		//Does not have an allocator obv.
		store = data;
		back = front = 0;
		allocator = null;
	}

	void grow()
	{
		size_t nc = store.length * 2;
		void[]  ns = allocator.allocateRaw(nc, 8);
		ns[0 .. back] = store[0 .. back];

		allocator.deallocate(store);
		store = ns;
	}

	void put(void[] data)
	{
		if(back + data.length > store.length)
			grow();

		store.ptr[back .. back + data.length] = data;
		back += data.length;
	}

	void[] take(size_t size)
	{
		void[] data = store[front .. front + size];
		front += size;
		return data;
	}

	bool hasData() 
	{
		return front != back;
	}
}

struct Serializer
{
	static void serialize(T)(auto ref T t, ref Blob b) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
	{
		b.put((&t)[0 .. 1]);
	}

	static T deserialize(T)(ref Blob b) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
	{
		return *cast(T*)(b.take(T.sizeof).ptr);
	}

	static size_t size(T)(auto ref T t) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
	{
		return T.sizeof;
	}	

	static void serialize(T)(T t, ref Blob b) if(isArray!T && !hasIndirections!(ElementType!T))
	{
		uint length = cast(uint)t.length;
		b.put((&length)[0 .. 1]);
		b.put(cast(void[])(t));
	}

	static T deserialize(T)(ref Blob b) if(isArray!T && !hasIndirections!(ElementType!T))
	{
		alias E = ElementType!T;
		uint s = *cast(uint*)(b.take(uint.sizeof).ptr);
		static if(is(T : E[n], size_t n))
		{
			T t;
			t[0 .. s] = cast(E[])(b.take(s * E.sizeof));
			return t;
		}
		else
			return cast(T)b.take(s * E.sizeof);
	}

	static size_t size(T)(auto ref T t) if(isArray!T && !hasIndirections!(ElementType!T))
	{
		alias E = ElementType!T;
		return uint.sizeof + E.sizeof * t.length;
	}

	static void serialize(T)(auto ref T t, ref Blob b) if(is(T == struct))
	{
		foreach(i, ref field; t.tupleof)
		{
			serialize(field, b);		
		}
	}

	static T deserialize(T)(ref Blob b) if(is(T == struct))
	{
		T t = void;
		foreach(ref field; t.tupleof)
			field = deserialize!(typeof(field))(b);
		return t;
	}

	static size_t size(T)(auto ref T t) if(is(T == struct))
	{
		size_t s = 0;
		foreach(ref field; t.tupleof)
			s += size(field);
		return s;
	}

	enum array_error = "%s cannot be %s as it contains indirections please flatten the structure.";
	static void serialize(T)(auto ref T t, ref Blob b) if(isArray!T && hasIndirections!(ElementType!T))
	{
		import std.conv, std.format;
		static assert(false, format(array_error, T.stringof, "serialized"));
	}

	static void deserialize(T)(ref Blob b) if(isArray!T && hasIndirections!(ElementType!T))
	{
		import std.conv, std.format;
		static assert(false, format(array_error, T.stringof, "deserialized"));
	}

	static size_t size(T)(auto ref T t) if(isArray!T && hasIndirections!(ElementType!T))
	{
		import std.conv, std.format;
		static assert(format(array_error, T.stringof, "sized"));
	}

}
