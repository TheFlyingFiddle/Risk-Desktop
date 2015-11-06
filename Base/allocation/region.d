module allocation.region;

public import allocation.common;

struct RegionAllocator
{
	nothrow:
	IAllocator base;

	void*  _buffer;
	void*  _offset;
	size_t _capacity; //Need to create a growing Region allocator. (Will be marginaly slower)

	size_t bytesAllocated() @property 
	{
		return cast(size_t)_offset - cast(size_t)_buffer;
	}

	size_t bytesRemaining() @property
	{
		return _capacity - bytesAllocated;
	}

	this(IAllocator allocator, size_t capacity, size_t alignment = 8)
	{
		this.base      = allocator;
		void[] buffer  = allocator.allocateRaw(capacity, alignment);
		this._buffer   = buffer.ptr;
		this._offset   = buffer.ptr;
		this._capacity = buffer.length;
	}

	this(void[] buffer)
	{
		this.base      = null;
		this._buffer   = buffer.ptr;
		this._offset   = buffer.ptr;
		this._capacity = buffer.length;
	}

	~this()
	{
		if(base)
			base.deallocate(_buffer[0 .. _capacity]);
	}
	
	void[] allocate_impl(size_t size, size_t alignment)
	{
		auto alignedOffset = aligned(_offset, alignment);
		auto offset = cast(void*)(cast(size_t)alignedOffset + size);
		
		//assert(bytesAllocated <= _capacity, "Out of memory");
		if(offset - _buffer >= _capacity)
			return null;
		
		_offset = offset;
		return alignedOffset[0 .. size];
	}

	void deallocate_impl(void[] dealloc)
	{
		//assert(0, "Should never call this");
	}
	
	void rewind(void* rewindPos)
	{
		assert(cast(size_t)rewindPos <= cast(size_t)_offset &&
			   cast(size_t)rewindPos >= cast(size_t)_buffer);
		
		this._offset = rewindPos;
	}
	
	void reset()
	{
		this._offset   = this._buffer;
	}


	@disable this(this);
}

void* aligned(void* ptr, size_t alignment) @nogc nothrow
{
	return cast(void*)((cast(size_t)ptr + (alignment - 1)) & ~(alignment - 1));
}

unittest
{
	import allocation;
	auto region = RegionAllocator(Mallocator.cit, 1024, 16);
	ubyte[] d = cast(ubyte[])region.allocateRaw(1024, 16);

	assert(d.length == 1024);
	assert(region.bytesAllocated() == 1024);
	assert(region.bytesRemaining() == 0);
}

//Good for allocating many as in 1000000+ small objects fast. 
//Can only deallocate all objects at once. As such it is usefull
//for serialization. 
struct RegionChain
{
	struct Node
	{
		RegionAllocator region;
		Node* next;
	}	

	IAllocator backing;
	size_t minSize;
	Node* list;
	this(IAllocator backing, size_t standardSize)
	{	
		this.minSize = standardSize;
		this.backing = backing;
		list = allocNode(minSize);
	}

	Node* allocNode(size_t size) nothrow
	{
		import std.c.stdio;

		auto memsize = Node.sizeof + size; 
		auto tmem  = backing.allocateRaw(memsize, 8);
		auto rmem  = (tmem.ptr + Node.sizeof)[0 .. size];
		ubyte[] nodemem = cast(ubyte[])tmem[0 .. Node.sizeof];
		nodemem[] = 0;
		Node* node = cast(Node*)(nodemem.ptr);
		node.region = RegionAllocator(rmem);
		node.next   = null;
		return node;
	}

	void[] allocate_impl(size_t size, size_t alignment) nothrow
	{
		import std.algorithm : max;
		auto mem = list.region.allocate_impl(size, alignment);
		if(mem.length) return mem;

		Node* node = allocNode(max(minSize, size));
		node.next  = list;
		list = node;
		return allocate_impl(size, alignment);
	}

	void deallocate_impl(void[] dealloc) nothrow
	{
		//assert(0, "Should never call this");
	}

	void deallocateAll()
	{
		Node* node = list;
		Node* next = list.next;
		while(node !is null)
		{
			void* nptr = cast(void*)node;
			backing.deallocate(nptr[0 .. Node.sizeof + node.region._capacity]);
			node = next;
			if(node !is null)
				next = node.next;
		}
	}
}	


struct RegionAppender(T)
{
	import collections.list, std.range;

	RegionAllocator* _allocator;
	void*            _rewindPos;
	T*               _buffer;
	size_t           _capacity;
	size_t           _offset;

	this(ref RegionAllocator allocator)
	{
		this(&allocator);
	}

	this(RegionAllocator* allocator, size_t alignment = T.alignof)
	{
		this._allocator = allocator;
		
		size_t bytes = (allocator.bytesRemaining() / T.sizeof);
		_rewindPos = this._allocator._offset; 

		T[] buffer = allocator.allocate!(T[])(bytes, alignment);
		_capacity  = buffer.length;
		_buffer    = buffer.ptr;
		_offset    = 0;
	}

	~this()
	{
		_allocator.rewind(_rewindPos);
	}	

	FixedList!T data()
	{
		return FixedList!T(_buffer, cast(uint)_offset, cast(uint)_offset);
	}

	FixedList!T take()
	{
		auto list = FixedList!T(_buffer, cast(uint)_offset, cast(uint)_offset);

		_rewindPos = cast(void*)&_buffer[_offset];
		_buffer    = cast(T*)_rewindPos;
		_offset    = 0;
		_capacity -= _offset;

		return list;
	}

	size_t put(T value)
	{
		assert(_offset < _capacity);
		_buffer[_offset++] = value;
        return _offset - 1;
	}

	void put(T[] value)
	{
		assert(_offset + value.length < _capacity);
		_buffer[_offset .. _offset + value.length] = value;
		_offset += value.length;
	}

	void put(Range)(Range range) if(isInputRange!Range && is(ElementType!Range : T))
	{
		foreach(ref elem; range)
			this.put(elem);
	}

	void clear()
	{
		_offset = 0;
	}

    ref T opIndex(size_t index)
	{
        assert(index < _capacity, "Index out of bounds");
        return _buffer[index];
	}

    void opIndexAssign(ref T value, size_t index)
	{
        assert(index < _capacity, "Index out of bounds");
        _buffer[index] = value;
	}

	@disable this(this);
}


//Can append.
unittest
{
	import allocation, collections.list;
	auto a = RegionAllocator(Mallocator.cit, 1024 * 2, 16);
	auto app  = RegionAppender!(ushort)(a);

	foreach(ushort i; 0 .. 1024) {
		app.put(i);
	}

	auto list = app.data;
	foreach(ushort i; 0 .. 1024) {	
		assert(list[i] == i);
	}
}

//Crash on overflow.
unittest
{
	import allocation;
	import std.exception, core.exception;
	auto a = RegionAllocator(Mallocator.cit, 1024 * 2, 16);
	auto app  = RegionAppender!(ushort)(a);
	foreach(ushort i; 0 .. 1024) app.put(i);

	assertThrown!AssertError(app.put(1));
}

