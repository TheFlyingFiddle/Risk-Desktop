module collections.deque;

//Need's to be tested.

import allocation;
struct Deque(T)
{
	IAllocator allocator;
	T* buffer;
	uint start, end, length, capacity;

	this(IAllocator allocator, size_t size)
	{
		this.buffer = allocator.allocate!(T[])(size).ptr;
		this.start  = 0;
		this.end    = 0;
		this.length = 0;
		this.capacity = size;
	}

	void resize()
	{
		T* nBuf = allocator.allocate!(T[])(this.capacity * 2 + 10).ptr;
		foreach(i, ref item; this)
			nBuf[i] = item;
		allocator.deallocate(buffer[0 .. capacity]); 

		this.start = 0;
		this.end   = length;
		this.capacity = this.capacity * 2 + 10;
		this.buffer   = nBuf;
	}

	void push(ref T value)
	{
		if((end + 1) % capacity == start)
			resize();

		end = (end + 1) % capacity;
		buffer[end] = value;
		length++;
	}	

	bool full()
	{
		return ((end + 1) % capacity) == start;
	}

	T pop() 
	{
		assert(length);
		T t = buffer[end];
		end = (end + capacity - 1) % capacity;
		length--;
		return t;
	}

	void enqueue(ref T value)
	{
		if(end == (start + capacity - 1) % capacity)
			resize();

		start = (start + capacity - 1) % capacity;
		buffer[start] = value;
		length++;
	}

	T dequeue()
	{
		assert(length);
		T t = buffer[start];
		start = (start + 1) % capacity;
		return t;
	}

	ref T opIndex(size_t index)
	{
		assert(index < length);
		return buffer[(start + index) % capacity];
	}

	int opApply(int delegate(ref T) dg)
	{
		int result;
		if(end >= start)
		{
			foreach(i; start .. end)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}
		} 
		else 
		{
			foreach(i; start .. capacity)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}

			foreach(i; 0 .. end)
			{
				result = dg(buffer[i]);
				if(result) return result;
			}
		}
		return result;
	}

	int opApply(int delegate(uint, ref T) dg)
	{
		int result;
		uint index = 0;
		if(end >= start)
		{
			foreach(i; start .. end)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}
		} 
		else 
		{
			foreach(i; start .. capacity)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}

			foreach(i; 0 .. end)
			{
				result = dg(index, buffer[i]);
				if(result) return result;
				index++;
			}
		}
		return result;
	}
}