module collections.map;

import allocation;
import std.algorithm;
import std.conv;

size_t defaultHash(K)(ref K k) @nogc nothrow
{
	import core.internal.hash;
	import std.traits;

	auto ptr = &bytesHash;
	auto r   = cast(size_t function(const void*,size_t,size_t) @nogc nothrow)ptr;

	static if(isArray!K)
		return r(k.ptr, k.length, 0);
	else static if(isIntegral!K)
		return cast(size_t)k;
	else 
		return r(&k, K.sizeof, 0);
}

struct HashMap(K, V, alias hashFun = defaultHash!K) 
{

	//Tightly packed!
	struct Element
	{
		K		key;
		V		value;
		uint	next;
	}

	struct FindResult
	{
		uint hashIdx;
		uint index;
		uint prev;
	}

	struct Rep
	{
		uint length;
		uint capacity;
		IAllocator allocator;
		uint* indices;
		Element* elements;
	}

	Rep* rep;
	@property ref uint length()
	{
		return rep.length;
	}

	@property ref uint capacity()
	{
		return rep.capacity;
	}

	@property ref IAllocator allocator()
	{
		return rep.allocator;
	}
	
	@property ref uint* indices()
	{
		return rep.indices;
	}

	@property ref Element* elements()
	{
		return rep.elements;
	}		

	this(IAllocator allocator, int initialSize = 4)
	{
		if(initialSize < 4) initialSize = 4;
		allocate(allocator, initialSize, rep);	
	}


	V* opBinaryRight(string op : "in")(K key) nothrow
	{
		auto res = find(key);
		return res.index == uint.max ? null : &elements[res.index].value;
	}

	void opIndexAssign(V value, K key) 
	{
		set(key, value);
	}

	ref V opIndex(K key) 
	{
		return get(key);
	}

	V* add(K k, V v) 
	{
		if(length == capacity)
			resize();

		auto res = addImpl(k, v);
		assert(res,text("Key already present in table!", k));
		return &elements[length - 1].value;
	}

	V* tryAdd(K k, V v)  nothrow
	{
		if(length == capacity)
			resize();

		auto res = addImpl(k,v);
		return res ? &elements[length - 1].value : null;
	}

	void set(K k, V v) 
	{
		auto element  = findOrFail(k);
		element.value = v;
	}

	ref V get(K k) 
	{
		auto element  = findOrFail(k);
		return element.value;
	}

	bool remove(K k) nothrow
	{
		auto res = find(k);
		if(res.index == uint.max)
			return false;

		removeImpl(res);
		return true;
	}

	bool has(K k) nothrow
	{
		auto res = find(k);
		return res.index != uint.max;
	}

	private void removeImpl(FindResult res)  nothrow
	{
		if(res.prev == uint.max)
			indices[res.hashIdx] = elements[res.index].next;
		else 
			elements[res.prev].next = elements[res.index].next;

		if(res.index != length - 1)
		{
			elements[res.index] = elements[length - 1];
			auto last = find(elements[res.index].key);

			if(last.prev == uint.max)
				indices[last.hashIdx]    = res.index;
			else 
				elements[last.prev].next = res.index; 
		}

		length--;
	}

	private bool addImpl(ref K k, ref V v)  nothrow
	{
		auto result = find(k);
		if(result.index == uint.max)
		{
			if(result.prev == uint.max)
			{
				//new item.
				indices[result.hashIdx] = length;
			}
			else 
			{
				elements[result.prev].next = length;
			}

			elements[length++] = Element(k, v, uint.max);
			return true;
		}
		else 
		{
			return false;
		}
	}

	private uint startIndex(ref K k)  nothrow
	{
		auto hash	= hashFun(k);
		return hash % (capacity * 2);
	}

	private FindResult find(ref K key)  nothrow
	{
		auto idx  = startIndex(key);
		if(indices[idx] == uint.max) 
			return FindResult(idx, uint.max, uint.max);

		FindResult result = FindResult(idx, indices[idx], uint.max);

		auto elem = elements[result.index];
		while(elem.key != key)
		{
			result.prev  = result.index;
			result.index = elem.next;
			if(elem.next == uint.max)
				break;

			elem  = elements[elem.next];
		}

		return result;
	}

	private Element* findOrFail(ref K key) 
	{
		auto result = find(key);
		assert(result.index != uint.max);
		return &elements[result.index];
	}


	void deallocate()
	{
		allocator.deallocate((cast(void*)this.rep)[0 .. allocationSize(capacity)]);
		this.rep = null;
	}


	private static uint allocationSize(uint capacity)
	{
		return Rep.sizeof + (uint.sizeof * 2 + Element.sizeof) * capacity;
	}	

	private void allocate(IAllocator allocator,
						  uint sz,
						  ref Rep* rep) nothrow
	{
		try
		{
			auto base	  = allocator.allocateRaw(allocationSize(sz), Element.alignof).ptr;

			rep				  = cast(Rep*)base;
			rep.indices		  = cast(uint*)(base + Rep.sizeof);
			rep.elements	  = cast(Element*)(base + Rep.sizeof + sz * uint.sizeof * 2);
			rep.length		  = 0;
			rep.capacity	  = sz;
			rep.allocator	  = allocator;

			rep.indices[0 .. sz * 2] = uint.max;
		}
		catch(Throwable t)
		{
			throw new Error(t.msg, t);
		}
	}

	private void resize() nothrow
	{
		auto oldRep = rep;

		allocate(oldRep.allocator, oldRep.capacity * 2 + 10, rep);

		
		try
		{
			foreach(i; 0 .. oldRep.capacity)
			{
				auto res = addImpl(oldRep.elements[i].key, oldRep.elements[i].value);
				assert(res, text("Key already present in table!", oldRep.elements[i].key));
			}

			allocator.deallocate((cast(void*)oldRep)[0 .. allocationSize(oldRep.capacity)]);
		}
		catch(Throwable t)
		{
			throw new Error(t.msg, t);
		}
	}

	int opApply(int delegate(ref K, ref V) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(elements[i].key, elements[i].value);
			if(result) break;
		}

		return result;
	}
}

unittest
{
	alias HM(K, V) = HashMap!(K, V);
	auto aa = HM!(string, int)(Mallocator.cit, 10);

	aa.add("One", 1);
	assert(aa.has("One") && aa["One"] == 1);
	aa.set("One", 2);
	assert(aa.has("One") && aa["One"] == 2);

	aa.remove("One");
	assert(!aa.has("One"));
}

unittest
{
	//Performance tests
	//import std.stdio;
	//import std.conv, std.stdio, std.random;
	//try
	//{
	//    alias HM(K, V) = HashMap!(K, V);
	//    auto aa = HM!(string, int)(Mallocator.cit, 10);
	//    int counter = 0;
	//    foreach(i; 0 .. 1000_000_0)
	//    {
	//        string s = text(i);
	//        aa.add(s, i);
	//    }
	//
	//    counter = 0;
	//    int[string] aa1;
	//    foreach(i; 0 .. 1000_000_0)
	//    {
	//        string s = text(i);
	//        aa1[s] = i;
	//        if(s in aa1) counter++;
	//
	//    }
	//
	//
	//    writeln("Build in aa");
	//    readln;
	//} 
	//catch(Throwable t)
	//{
	//    writeln(t);
	//    readln;
	//}
}