module collections.map;

import allocation;
import std.algorithm;
import std.conv;

size_t defaultHash(K)(ref K k) @nogc nothrow pure
{
	import core.internal.hash;
	import std.traits;

	auto ptr = &bytesHash;
	auto r   = cast(size_t function(const void*,size_t,size_t) @nogc nothrow pure)ptr;

	static if(isArray!K)
		return r(k.ptr, k.length, 0);
	else static if(isIntegral!K)
		return cast(size_t)k;
	else 
		return r(&k, K.sizeof, 0);
}

struct FindResult
{
	uint hashIdx;
	uint index;
	uint prev;
}

private auto allocate(K, V, alias hf = defaultHash!T)(IAllocator allocator, size_t sz) nothrow
{
	alias M = MHash!(K, V, hf);

	M* m;
	size_t allocSize = M.sizeof + (uint.sizeof * 2 + M.Element.sizeof) * sz;
	auto base	  = cast(ubyte[])allocator.allocateRaw(allocSize, M.Element.alignof);
	base[] = 0;
	
	m				  = cast(M*)base.ptr;
    m.indices		  = cast(uint*)(base.ptr + M.sizeof);
	m.elements		  = cast(M.Element*)(base.ptr + M.sizeof + uint.sizeof * 2 * sz);
	m.length		  = 0;
	m.capacity        = sz;
	m.indices[0 .. sz * 2] = uint.max;

	return m;
}

void deallocate(K, V, alias hf = defaultHash!T)(IAllocator allocator, ref MHash!(K,V,hf)* m)
{
	import allocation;
	alias M = MHash!(K, V, hf);
	size_t allocSize = M.sizeof + (uint.sizeof * 2 + M.Element.sizeof) * m.capacity;
	allocator.deallocate((cast(void*)m)[0 .. allocSize]);
	m = null;
}

private auto reallocate(K, V, alias hf = defaultHash!T)(IAllocator allocator, size_t sz, ref MHash!(K,V,hf)* m) nothrow
{
	alias M = MHash!(K, V, hf);
	auto oldM = m;
    auto newM = allocate!(K,V, hf)(allocator, sz);

	foreach(i; 0 .. oldM.capacity) {
		auto last = newM.findLast(oldM.elements[i].key);
		newM.add(oldM.elements[i].key, oldM.elements[i].value, last);
	}

	deallocate(allocator, m);
	return newM;
}

struct MHash(K, V, alias hf = defaultHash!T)
{
	//Tightly packed!
	struct Element
	{
		K		key;
		V		value;
		uint	next;
	}
	nothrow pure:

	uint length;
	uint capacity;
	@(x => x.capacity * 2) uint* indices;
	@(x => x.capacity)     Element* elements;

	//Will remove all incase of multimap!
	bool removeFirst(K k) nothrow
	{
		auto res = find(k);
		if(res.index == uint.max)
			return false;

		remove(res);
		return true;
	}

	size_t removeAll()(K k) nothrow
	{
		size_t removed = 0;
		while(true)
		{
			//Slow version.
			auto res = find(k);
			if(res.index == uint.max)
				break;

			remove(res);
			removed++;
		}
		return removed;
	}

	bool has(K k) nothrow
	{
		auto res = find(k);
		return res.index != uint.max;
	}

	size_t hasCount()(K k) nothrow
	{
		auto res = find(k);
		size_t count = 0;
		while(res.index != uint.max)
		{
			if(elements[res.index].key == k)
				count++;
			res.index = elements[res.index].next;
		}
		return count;
	}

	auto range()(K key) nothrow
	{
		struct Iterator
		{
			MHash!(K, V, hf)* this_;
			FindResult result;
			K key;
			V front;
			
			this(K key, MHash!(K, V, hf)* this_)
			{
				this.this_ = this_;
				this.result = this_.find(key);
				this.key    = key;
				if(!empty())
					this.front = this_.elements[result.index].value;
			}

			bool empty() { return result.index == uint.max; }

			void popFront() 
			{ 
				do
				{
					result.prev  = result.index;
					result.index = this_.elements[result.index].next; 
				} while(result.index != uint.max && this_.elements[result.index].key != key);

				if(result.index != uint.max)
					this.front = this_.elements[result.index].value;
			}
			
			void remove()
			{
				auto saved = result;
				saved.index = this_.elements[result.index].next;
				this_.remove(result);
				result = saved;
			}

		}

		return Iterator(key, &this);
	}

	private void remove(ref FindResult res)  nothrow
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

	private void add(ref K k, ref V v, ref FindResult result)  nothrow
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
	}

	private uint startIndex(ref K k)  nothrow
	{
		auto hash	= hf(k);
		return hash % (capacity * 2);
	}

	private Element* findOrFail(ref K key)
	{
		auto res = find(key);
		assert(res.index != uint.max);
		return &elements[res.index];
	}

	private FindResult findLast(ref K key) nothrow
	{
		auto res = find(key);
		if(res.index == uint.max)
			return res;

		res.prev  = res.index;
		auto elem = elements[res.index];
		while(elem.next != uint.max)
		{
			res.prev  = res.index;
			res.index = elem.next;
			elem = elements[res.index];
		}

		return res;
	}

	private FindResult find(ref K key)  nothrow
	{
		auto idx  = startIndex(key);
		if(indices[idx] == uint.max) 
			return FindResult(idx, uint.max, uint.max);

		FindResult result = FindResult(idx, indices[idx], uint.max);
		int idid = result.index;

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
}

struct Map(K, V, alias hf = defaultHash!K) 
{
	//Tightly packed!
	alias M = MHash!(K, V, hf);
	alias Element = M.Element;

	IAllocator allocator;
	M* rep;

	ref uint length() { return rep.length; }
	ref uint capacity() { return rep.capacity; }
	ref uint* indices() { return rep.indices; }
	ref Element* elements() { return rep.elements; }		

	this(IAllocator allocator, int initialSize = 4)
	{
		if(initialSize < 4) initialSize = 4;
		rep = allocate!(K, V, hf)(allocator, initialSize);	
	}

	V* opBinaryRight(string op : "in")(K key) nothrow pure
	{
		auto res = rep.find(key);
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

	bool opEquals(ref Map!(K, V, hf) other) nothrow pure @nogc
	{
		if(other.length < this.length) return false;
		foreach(ref e; rep.elements[0 .. rep.length])
		{
			auto p = e.key in other;
			if(!p || *p != e.value) return false;
		}
		return true;
	}

	V* add(K k, V v) 
	{
		if(length == capacity)
			rep = reallocate!(K, V, hf)(this.allocator, this.capacity * 2 + 10, rep);

		auto res = rep.find(k);
		assert(res.index == uint.max,text("Key already present in table!", k));
		rep.add(k, v, res);
		return &elements[length - 1].value;
	}

	V* tryAdd(K k, V v)  nothrow
	{
		if(length == capacity)
			rep = reallocate!(K, V, hf)(this.allocator, this.capacity * 2 + 10, rep);

		auto res = rep.find(k);
		if(res.index != uint.max)
			return null;

		rep.add(k, v, res);
		return &elements[length - 1].value;
	}

	void set(K k, V v) 
	{
		auto element  = rep.findOrFail(k);
		element.value = v;
	}

	ref V get(K k) 
	{
		auto element  = rep.findOrFail(k);
		return element.value;
	}

	bool remove(K k) nothrow
	{
		return rep.removeFirst(k);
	}

	bool has(K k) nothrow
	{
		return rep.has(k);
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


struct MultiMap(K, V, alias hf  = defaultHash!K)
{
	//Tightly packed!
	alias M = MHash!(K, V, hf);
	alias Element = M.Element;

	IAllocator allocator;
	M* rep;

	ref uint length() nothrow { return rep.length; }
	ref uint capacity() nothrow { return rep.capacity; }
	ref uint* indices() nothrow { return rep.indices; }
	ref Element* elements() nothrow { return rep.elements; }		

	this(IAllocator allocator, int initialSize = 4)
	{
		if(initialSize < 4) initialSize = 4;
		rep = allocate!(K, V, hf)(allocator, initialSize);	
	}

	bool opEquals(ref MultiMap!(K, V, hf) other) nothrow pure @nogc 
	{
		if(other.length < this.length) return false;
		foreach(ref k, ref v; this)
		{
			auto p = k in other;
			if(!p || *p != v) return false;
		}
		return true;
	}

	auto opIndex(K key) 
	{
		return rep.range(key);
	}

	V* add(K k, V v) 
	{
		if(length == capacity)
			rep = reallocate!(K, V, hf)(this.allocator, this.capacity * 2 + 10, rep);

		auto last = rep.findLast(k);
		rep.add(k, v, last);
		return &elements[length - 1].value;
	}

	auto get(K k) 
	{
		return rep.range(k);
	}

	bool removeFirst(K k) nothrow
	{
		return rep.removeFirst(k);
	}

	size_t removeAll(K k) nothrow
	{
		return rep.removeAll!()(k);
	}

	size_t count(K k) nothrow
	{
		return rep.hasCount!()(k);
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

struct SMap(K, V, ubyte size = 64, alias hf = defaultHash!K)
{
	import std.algorithm;

	@nogc nothrow:

	align(1) struct Element
	{	
		@nogc nothrow:
		align(1):
		K key;
		V value;
		ubyte next;
	}

	enum capacity = size == ubyte.max ? size - 1 : size;

	ubyte length;
	ubyte[capacity]		  indices;
	Element[capacity + 1] elements;
	
	struct FindResult
	{
		uint hashIdx;
		ubyte index;
		ubyte prev;
	}
	
	private FindResult find(ref K key)  nothrow
	{
		auto hashIdx = cast(uint)(hf(key) % capacity);
		auto idx	 = indices[hashIdx];
		
		//No item found. 
		if(idx == 0) 
			return FindResult(hashIdx, 0, 0);

		FindResult result = FindResult(hashIdx, idx, 0);
		auto elem = elements[result.index];
		ubyte cl = 0;
		while(elem.key != key)
		{
			cl++;
			result.prev  = result.index;
			result.index = elem.next;
			if(elem.next == 0)
				break;

			elem  = elements[elem.next];
		}

		return result;
	}

	void add(K k, V v) 
	{
		assert(length < capacity);	
		auto result = find(k);
		assert(result.index == 0, "Item already present!");
		length++;
		if(result.prev == 0)
		{
			//new item.
			indices[result.hashIdx] = length;
		}
		else 
		{
			elements[result.prev].next  = length;
		}

		elements[length] = Element(k, v, 0);
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
		if(res.index == 0)
			return false;

		if(res.prev == 0)
			indices[res.hashIdx] = elements[res.index].next;
		else 
		{
			elements[res.prev].next = elements[res.index].next;
		}

		if(res.index != length - 1)
		{
			elements[res.index] = elements[length - 1];
			auto last = find(elements[res.index].key);

			if(last.prev == 0)
				indices[last.hashIdx]    = res.index;
			else 
				elements[last.prev].next = res.index; 
		}

		length--;
		return true;
	}

	bool has(K k) nothrow
	{
		auto res = find(k);
		return res.index != 0;
	}

	private Element* findOrFail(ref K key) 
	{
		auto result = find(key);
		assert(result.index != 0);
		return &elements[result.index];
	}

	V* opBinaryRight(string op : "in")(K key) nothrow
	{
		auto res = find(key);
		return res.index == 0 ? null : &elements[res.index].value;
	}

	void opIndexAssign(V value, K key) 
	{
		set(key, value);
	}

	ref V opIndex(K key) 
	{
		return get(key);
	}

	int opApply( int delegate(ref K, ref V) nothrow @nogc dg)
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
	alias HM(K, V) = Map!(K, V);
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
	import std.algorithm, std.range;
	auto mm = MultiMap!(string, int)(Mallocator.cit, 10);
	mm.add("One", 1);
	mm.add("One", 2);
	assert(mm.count("One") == 2);
	assert(mm["One"].equal([1, 2]));
	mm.removeFirst("One");
	assert(mm.count("One") == 1);
	assert(mm["One"].equal([2]));
}

unittest
{

	auto mm = MultiMap!(int, int)(Mallocator.cit, 10);
	mm.add(2, 1);
	mm.add(2, 2);
	mm.add(22, 3);
	assert(mm.count(2) == 2);
	assert(mm[2].equal([1, 2]));
	mm.removeFirst(2);
	assert(mm.count(2) == 1);
	assert(mm[2].equal([2]));
}

unittest
{
	SMap!(uint, uint) sm;
	
	sm.add(10, 100);
	assert(sm.has(10) && sm[10] == 100);
	sm.add(200, 21);
	assert(sm.has(200) && sm[200] == 21 &&
		   sm.has(10) && sm[10] == 100);
	sm.set(10, 42);
	assert(sm.has(10) && sm[10] == 42);
	sm.remove(10);
	assert(!sm.has(10) && sm.has(200));
}

unittest
{
	SMap!(uint, uint, ubyte.max) items;

	import std.random;
	uint[ubyte.max] keys;
	uint[ubyte.max] values;
	foreach(i; 0 .. items.capacity)
	{
		keys[i] = uniform(0, uint.max);
		values[i] = uniform(0, uint.max);
		items.add(keys[i], values[i]);
	}


	foreach(i; 0 .. items.capacity)
		assert(items[keys[i]] == values[i]);

	foreach(i; 0 .. items.capacity)
	{
		items.remove(keys[i]);
		assert(!items.has(keys[i]));
	}

	int k = 5;
	assert(k == 5);
}

unittest
{
	//Performance tests
	//import std.stdio;
	//import std.conv, std.stdio, std.random;
	//try
	//{
	//    alias HM(K, V) = Map!(K, V);
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