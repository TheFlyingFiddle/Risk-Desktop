module inplace;

struct InplaceString(size_t N=256) if(N <= 256)
{
	ubyte length;
	char[N] str;

	this(const(char)[] s) 
	{
		assert(s.length <= N);
		length = cast(ubyte)s.length;
		str[0 .. length] = s;
	}

	string value() const 
	{
		return cast(string)str[0 .. length];
	}

	alias this value;
}

struct InplaceArray(T, size_t N)
{
	ubyte	length;
	T[N]	data;

	this(R)(ref R range)
	{
		import std.algorithm;
		auto r = range;
		size_t size = r.count;
		assert(size <= N);
		size_t idx = 0;
		foreach(elem; range)
		{
			data[idx++] = elem;
		}

		length = size;
	}

	void add(T t) 
	{ 
		assert(length < N);
		data[length++] = t; 
	}

	T[] value() const { return data[0 .. length]; }
	alias this value;
}