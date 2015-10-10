module allocation;

public import allocation.gc;
public import allocation.native;
public import allocation.region;
public import allocation.stack;
public import allocation.common;
public import allocation.freelist;

__gshared static Mallocator GlobalAllocator;

private static RegionAllocator p_scratch_alloc;
private __gshared static size_t scratch_space;

RegionAllocator* scratch_alloc()
{
	return &p_scratch_alloc;
}

void initializeScratchSpace(size_t spaceSize)
{
	scratch_space = spaceSize;
	p_scratch_alloc = RegionAllocator(Mallocator.cit, scratch_space);
}

static this()
{
	if(scratch_space) 
	{
		p_scratch_alloc = RegionAllocator(Mallocator.cit, scratch_space);
	}
}

static ~this()
{
	//Ugly but it does the job!
	p_scratch_alloc.__dtor();
}