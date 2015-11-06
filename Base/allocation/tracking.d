module allocation.tracking;

import allocation;
import collections.list;

public import allocation : IAllocator;

class TrackAllocator : IAllocator
{
	IAllocator allocator;
	List!(void[]) allocations;

	static TrackAllocator make(IAllocator allocator, size_t items = 10)
	{
		return allocator.allocate!TrackAllocator(allocator, items);
	}

	this(IAllocator alloc, size_t items)
	{
		this.allocator   = alloc;
		this.allocations = List!(void[])(alloc, items);
	}

	void dispose()
	{
		deallocateAll();
		
		auto a = this.allocator;
		this.allocator = null;
		a.deallocate(this);
	}

	void[] allocate_impl(size_t size, size_t alignment)
	{		
		auto mem = allocator.allocate_impl(size, alignment);
		allocations ~= mem;
		return mem;
	}	

	void deallocate_impl(void[] mem)
	{
		import std.algorithm.searching : countUntil;
		auto idx = allocations.countUntil!(x => x.ptr == mem.ptr && x.length == mem.length);
		assert(idx != -1);
		allocations.removeAt(idx);
		allocator.deallocate_impl(mem);
	}

	void deallocateAll()
	{
		for(int i = 0; i < allocations.length; i++)
		{
			allocator.deallocate_impl(allocations[i]);
		}
		allocations.deallocate();
	}
}
