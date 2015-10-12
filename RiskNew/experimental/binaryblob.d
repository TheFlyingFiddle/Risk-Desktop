module experimental.binaryblob;

import allocation;

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
struct BinaryBlob
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

	bool empty() 
	{
		return front == back;
	}
}