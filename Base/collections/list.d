module collections.list;

import std.traits;
import allocation.common;
import std.conv;

template isList(T)
{
	static if(is(T t == FixedList!U, U) || 
			  is(T t == List!U, U) ||
			  is(T t == SList!(U, N), U, size_t N))
		enum isList = true;
	else 
		enum isList = false;
}

alias fstring = FixedList!char;
struct FixedList(T)
{
	import std.range : isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange;
	
	static assert(isInputRange!(FixedList!T));
	static assert(isForwardRange!(FixedList!T));
	static assert(isBidirectionalRange!(FixedList!T));
	static assert(isRandomAccessRange!(FixedList!T));

	
	//This could potentially length + capacity at the begining of the buffer
	//instead. This would lead to reference like behaviour.
	T* buffer;
	uint length, capacity;

	@property const(T)[] array()
	{
		return buffer[0 .. length];
	}

	T* ptr() { return buffer; }

	this(Allocator)(ref Allocator allocator, size_t capacity)
	{
		T[] buffer = allocator.allocate!(T[])(capacity);
		this(buffer);
	}

	this(T[] buffer)
	{
		this.buffer = buffer.ptr;
		this.length = 0;
		this.capacity = cast(uint)buffer.length;
	}

	this(T* buffer, size_t length, size_t capacity)
	{
		this.buffer   = buffer;
		this.length   = cast(uint)length;
		this.capacity = cast(uint)capacity; 
	}

	void deallocate(A)(ref A allocator)
	{
		//This is ofc only valid if allocated through a allocator
		//That accepts deallocate!
		allocator.deallocate(buffer[0 .. capacity]);
	}

	ref T opIndex(size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		return buffer[index];
	}

	void opOpAssign(string s : "~")(auto ref T value)
	{
		assert(length < capacity, "The list is full can no longer append!");
		buffer[length++] = value;
	}

	void opOpAssign(string s : "~", Range)(Range range)
	{
		put(range);
	}

	void opIndexAssign(ref T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer[index] = value;
	}

	void opIndexAssign(T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer[index] = value;
	}

	void opSliceAssign()(auto ref T value)
	{
		buffer[0 .. length] = value;
	}

	void opSliceAssign()(auto ref T value,
						 size_t x,
						 size_t y)
	{
		assert(x <= y && x < length && y < length, text("A list was siced outsize of it's bounds! Length: ",  length, " Slice: ", x ," ", y));
		buffer[x .. y] = value;
	}


	size_t opDollar(size_t pos)()
	{
		return length;
	}

	bool opEquals(FixedList!T other)
	{
		if(other.length != this.length)
			return false;

		foreach(i; 0 .. this.length) {
			if (this[i] != other[i])
				return false;
		}
		return true;
	}

	FixedList!T opSlice()
	{
		return FixedList!T(buffer, length, capacity);
	}

	FixedList!T opSlice(size_t x, size_t y)
	{
		assert(x <= y && x <= length && y <= length, text("[", x, " .. ", y, "] Length: ", length));
		T* b = &buffer[x];
		uint length = cast(uint)(y - x);
		return FixedList!T(b, length, length);
	}	

	int opApply(int delegate(ref T) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(buffer[i]);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(uint, ref T) dg) 
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(i, buffer[i]);
			if(result) break;
		}
		return result;
	}


	void clear()
	{
		this.length = 0;
	}
	
	void insert(size_t index, T value)
	{
		assert(length < capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length)
			buffer[i + 1] = buffer[i];
		
		buffer[index] = value;
		length++;
	}

	void insert(size_t index, const(T)[] range)
	{
		assert(length + range.length <= capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length + range.length)
			buffer[i + range.length] = buffer[i];

		buffer[index .. index + range.length] = cast(T[])range;
		length += range.length;
	}

	//Range interface
	@property FixedList!T save() { return this; }
	@property bool empty() { return length == 0; }

	@property ref T front() { return *buffer; }
	@property ref T back()  { return buffer[length - 1]; }
	void popFront() {
		length--;
		buffer++;
	}
	void popBack() 
	{
		length--;
	}

	void put(T data)
	{
		this ~= data;
	}

	void put(T[] data)
	{
		foreach(ref d; data)
			put(d);
	}

	void put(const(T[]) data)
	{
		put(cast(T[])data);
	}

	void put(Range)(Range r)
	{
		foreach(ref item; r)
		{
			put(item);
		}
	}

	//Need to work around strings. (They are annoying)
	static if(is(T == char))
	{
		void put(dchar c)
		{
			import std.utf;
			Unqual!char[dchar.sizeof] arr;
			auto len = std.utf.encode(arr, c);
			put(arr[0 .. len]);
		}

		void put(string s)
		{
			foreach(char c; s)
				this ~= c;
		}

		void put(const(char)[] s)
		{
			foreach(char c; s)
				this ~= c;
		}
	}
}

alias String = List!char;
struct List(T)
{
	import std.range : isInputRange, isForwardRange, isBidirectionalRange, isRandomAccessRange,
					   hasSlicing;
	static assert(isInputRange!(List!T));
	static assert(isForwardRange!(List!T));
	static assert(isBidirectionalRange!(List!T));
	static assert(isRandomAccessRange!(List!T));


	enum defaultStartCapacity = 4;

	FixedList!(T) base_;
	alias base_ this;
	IAllocator allocator;


	this(IAllocator allocator, size_t startCapacity = defaultStartCapacity)
	{
		this.allocator = allocator;
		this.base_	   = FixedList!T(allocator, startCapacity);
	}

	private void reallocate()
	{
		size_t val = base_.capacity <  defaultStartCapacity ? defaultStartCapacity : base_.capacity;
		auto new_ = FixedList!T(allocator, cast(size_t)(val * 1.5));
		new_.length = base_.capacity;
		(cast(T[])new_.array)[] = cast(T[])base_.array;

		base_.deallocate(allocator);
		base_ = new_;
	}

	void deallocate()
	{
		base_.deallocate(allocator);
	}

	ref T opIndex(size_t index)
	{
		return base_[index];
	}

	void opOpAssign(string s : "~")(auto ref T value)
	{
		if(base_.capacity == base_.length)
			reallocate();

		base_.opOpAssign!s(value);
	}

	void opOpAssign(string s : "~", Range)(Range range)
	{
		foreach(item; range)
			this ~= item;
	}

	void opIndexAssign(ref T value, size_t index)
	{
		base_.opIndexAssign(value, index);
	}

	void opIndexAssign(T value, size_t index)
	{
		base_.opIndexAssign(value, index);
	}

	void opSliceAssign()(auto ref T value)
	{
		base_.opSliceAssign(value);
	}

	void opSliceAssign()(auto ref T value,
						 size_t x,
						 size_t y)
	{
		base_.opSliceAssign(value, x, y);
	}


	size_t opDollar(size_t pos)()
	{
		return base_.opDollar!(pos)();
	}

	bool opEquals(ref List!T other)
	{
		return base_.opEquals(other.base_);
	}

	FixedList!T opSlice()
	{
		return base_.opSlice();
	}

	FixedList!T opSlice(size_t x, size_t y)
	{
		return base_.opSlice(x, y);
	}	



	int opApply(int delegate(ref T) dg)
	{
		return base_.opApply(dg);
	}

	int opApply(int delegate(uint, ref T) dg)
	{
		return base_.opApply(dg);
	}

	void clear()
	{
		base_.clear();
	}

	void insert(size_t index, T value)
	{
		if(base_.capacity == base_.length)
			reallocate();

		base_.insert(index, value);
	}

	void insert(size_t index, const(T)[] range)
	{
		while(base_.capacity >= base_.length + range.length)
			reallocate();

		base_.insert(index, range);
	}

	bool remove(SwapStrategy s = SwapStrategy.stable)(ref T value)
	{
		return base_.remove!(s, T)(value);
	}


	bool removeAt(SwapStrategy s = SwapStrategy.stable)(size_t index)
	{
		return base_.removeAt!(s, T)(index);
	}

	@property List!T save() { return this; }
	@property bool empty() { return base_.length == 0; }

	@property ref T front() { return base_.front; }
	@property ref T back()  { return base_.back; }
	
	void popFront() { base_.popFront(); }
	void popBack() { base_.popBack(); }
	void put(T data) { this ~= data; }
	void put(T[] data) { this ~= data; }
}

alias cstring(size_t N) = SList!(char, N);
struct SList(T, size_t N)
{
	static if(N <= ubyte.max)
		alias size = ubyte;
	else static if(N <= ushort.max)
		alias size = ushort;
	else static if(N <= uint.max)
		alias size = uint;

	size length;
	T[N] buffer;
	enum capacity = N;

	const(T)[] array()
	{
		return buffer[0 .. length];
	}

	T* ptr() { return &buffer[0]; }
		
	this(T[] buffer)
	{
		this.buffer[0 .. buffer.length] = buffer;
		this.length = 0;
	}

	this(T* buffer, size_t length, size_t capacity)
	{
		this.buffer[0 .. length] = buffer[0 .. length];
		this.length   = cast(size)length;
	}

	ref T opIndex(size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		return buffer.ptr[index];
	}

	void opOpAssign(string s : "~")(auto ref T value)
	{
		assert(length < capacity, "The list is full can no longer append!");
		buffer.ptr[length++] = value;
	}

	void opOpAssign(string s : "~", Range)(Range range)
	{
		put(range);
	}

	void opIndexAssign(ref T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer.ptr[index] = value;
	}

	void opIndexAssign(T value, size_t index)
	{
		assert(index < length, text("A list was indexed outsize of it's bounds! Length: ", length, " Index: ", index));
		buffer.ptr[index] = value;
	}

	void opSliceAssign()(auto ref T value)
	{
		buffer.ptr[0 .. length] = value;
	}

	void opSliceAssign()(auto ref T value,
						 size_t x,
						 size_t y)
	{
		assert(x <= y && x < length && y <= length, text("A list was siced outsize of it's bounds! Length: ",  length, " Slice: ", x ," ", y));
		buffer.ptr[x .. y] = value;
	}


	size_t opDollar(size_t pos)()
	{
		return length;
	}

	bool opEquals(ref SList!(T, N) other)
	{
		if(other.length != this.length)
			return false;

		foreach(i; 0 .. this.length) {
			if (this[i] != other[i])
				return false;
		}
		return true;
	}

	T[] opSlice()
	{
		return buffer.ptr[0 .. length];
	}

	T[] opSlice(size_t x, size_t y)
	{
		assert(x <= y && x <= length && y <= length, text("[", x, " .. ", y, "] Length: ", length));
		T* b = &buffer[x];
		uint length = cast(uint)(y - x);
		return buffer.ptr[x .. y];
	}	

	int opApply(int delegate(ref T) dg)
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(buffer[i]);
			if(result) break;
		}
		return result;
	}

	int opApply(int delegate(uint, ref T) dg) 
	{
		int result;
		foreach(i; 0 .. length)
		{
			result = dg(i, buffer[i]);
			if(result) break;
		}
		return result;
	}

	void clear()
	{
		this.length = 0;
	}

	void insert(size_t index, T value)
	{
		assert(length < capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length)
			buffer[i + 1] = buffer[i];

		buffer[index] = value;
		length++;
	}

	void insert(size_t index, const(T)[] range)
	{
		assert(length + range.length <= capacity, text("Cannot insert outside of bounds! Length: ", length, " Index: ", index));

		foreach_reverse(i; index .. length + range.length)
			buffer[i + range.length] = buffer[i];

		buffer[index .. index + range.length] = cast(T[])range;
		length += range.length;
	}

	void put(T data)
	{
		this ~= data;
	}

	void put(T[] data)
	{
		foreach(ref d; data)
			put(d);
	}

	void put(const(T[]) data)
	{
		put(cast(T[])data);
	}

	void put(Range)(Range r)
	{
		foreach(ref item; r)
		{
			put(item);
		}
	}

	//Need to work around strings. (They are annoying)
	//Since they work with dchar... which is retarded imho.
	static if(is(T == char))
	{
		void put(dchar c)
		{
			import std.utf;
			Unqual!char[dchar.sizeof] arr;
			auto len = std.utf.encode(arr, c);
			put(arr[0 .. len]);
		}

		void put(const(char)[] s)
		{
			foreach(char c; s)
				this ~= c;
		}
	}
}

import std.algorithm : SwapStrategy, countUntil, swap;
bool remove(SwapStrategy s = SwapStrategy.stable, L, T)(ref L!T list, auto ref T value) if(isList!T)
{	
	@nogc bool fn(T x) { return x == value; }
	return remove!(fn, s, T)(list);
}

bool removeAt(SwapStrategy s = SwapStrategy.stable, L)(ref L list, size_t index) if(isList!L)
{
	assert(index < list.length, text("Cannot remove outsize of bounds! 
		   Length: ",  list.length, " Index: ", cast(ptrdiff_t)index)); 

	static if(s == SwapStrategy.unstable)
	{
		swap(list[list.length - 1], list[index]);
		list.length--;
	}
	else 
	{
		foreach(i; index .. list.length - 1)
			list[i] = list[i + 1];

		list.length--;
	}
	return true;
}

bool removeSection(SwapStrategy s = SwapStrategy.stable, L)(ref L list, size_t start, size_t end) if(isList!T)
{
	foreach(i; start .. end)
		removeAt(list, start);

	return true;
}

bool remove(alias pred, SwapStrategy s = SwapStrategy.stable, L)(ref L list) if(isList!T)
{
	import std.algorithm;
	auto index = list.countUntil!(pred)();
	if(index == -1) return false;

	static if(s == SwapStrategy.unstable)
	{
		swap(list[list.length - 1], list[index]);
		list.length--;
	}
	else 
	{
		foreach(i; index .. list.length - 1)
			list[i] = list[i + 1];

		list.length--;
	}

	return true;
}

void move(SwapStrategy s = SwapStrategy.stable, L1, L2)(ref L1 from, ref L2 to, uint index)
{
	auto item = from[index];
	removeAt!(s, T)(from, index);
	to ~= item;
}

unittest
{
	FixedList!int i;
	foreach(j, ref item; i){ }
}
