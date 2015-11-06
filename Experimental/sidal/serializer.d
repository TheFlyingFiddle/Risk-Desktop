module sidal.serializer;
import sidal.parser;
import std.traits;
import allocation;
import allocation.tracking;
import collections.list;

enum EncodeMode { a }
enum DecodeMode { a }

enum ErrorCode : ubyte
{
	none = 0,
	integerOverflow = 1,
	wrongType = 2,
	bufferOverflow = 3,
	unnamed	= 4,
	toManyFields = 5,
	unbalancedParens = 6,
}

struct SidalAllocator
{
	TrackAllocator track;
	RegionChain    string;
	this(IAllocator allocator)
	{
		import allocation : allocateRaw;
		track    = TrackAllocator.make(allocator, 10);
		string   = RegionChain(allocator, 1024 * 64);
	}

	char[] allocate(size_t size) nothrow
	{
		return cast(char[])string.allocateRaw(size, 1);
	}

	void deallocateAll()
	{
		track.deallocateAll();
		string.deallocateAll();
	}
}

struct SidalItem(T) if(hasIndirections!T)
{
	SidalAllocator allocator;
	T value;
	alias value this;

	void deallocate()
	{
		allocator.deallocateAll();
		value = T.init;
	}
}	

T decodeSIDAL(T, Source)(auto ref Source s) if(!hasIndirections!T)
{ 
	char[1024 * 16] buffer = void;
	SidalDecoder d = SidalDecoder(s, buffer, SidalAllocator.init);

	assert(d.token.tag == TokenTag.type);
	assert(d.token.value == T.stringof);

	d.nextToken();
	assert(d.token.tag == TokenTag.name);
	d.nextToken();

	T t = T.init;
	auto err = d.decode(t);
	assert(err == ErrorCode.none);
	return t;
}

SidalItem!T decodeSIDAL(T, Source)(auto ref Source s, IAllocator alloc) if(hasIndirections!T)
{
	char[1024 * 64] buffer = void;
	SidalDecoder d = SidalDecoder(s, buffer, SidalAllocator(alloc));

	assert(d.token.tag == TokenTag.type);
	assert(d.token.value == T.stringof);

	d.nextToken();
	assert(d.token.tag == TokenTag.name);
	d.nextToken();

	T t = T.init;
	auto err = d.decode(t);
	assert(err == ErrorCode.none);

	return SidalItem!T(d.allocator, t); 
}


struct SidalDecoder
{
	SidalAllocator allocator;
	SidalParser parser;
	ref SidalToken token() nothrow { return parser.token; }
	void nextToken() nothrow
	{ 
		parser.popFront(); 
	}

	this(T)(auto ref T t, char[] buffer, SidalAllocator alloc)
	{
		this.allocator = alloc;
		this.parser = SidalParser(t, buffer);
	}

	ErrorCode decode(T)(ref T t)
	{
		if(token.tag == TokenTag.type) 
		{
			if(token.value != T.stringof) return ErrorCode.wrongType;
			nextToken();
		}	

		//More stuff and stuff here. 
		return .decode!T(this, t);
	}

	@disable this(this);
}

private alias Decoder = SidalDecoder;

nothrow:
ErrorCode decode(T)(ref Decoder d, ref T t) if(isIntegral!T)
{
	if(d.token.tag != TokenTag.integer) return ErrorCode.wrongType;
	
	static if(is(T == ulong) || is(T == long))
		t = d.token.integer;
	else static if(isUnsigned!T)
	{
		if(d.token.integer > T.max) return ErrorCode.integerOverflow;
		t = cast(T)d.token.integer;
	}
	else
	{
		long tmp = d.token.integer;
		if(tmp > T.max || tmp < T.min) return ErrorCode.integerOverflow;
		t = cast(T)tmp;
	}

	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decode(T)(ref Decoder d, ref T t) if(isFloatingPoint!T)
{
	if(d.token.tag == TokenTag.floating)
		t = d.token.floating;
	else if(d.token.tag == TokenTag.integer)
		t = d.token.integer;
	else 
		return ErrorCode.wrongType;

	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decode(T)(ref Decoder d, ref T t) if(is(T == bool))
{
	if(d.token.tag != TokenTag.integer) return ErrorCode.wrongType;
	t = d.token.integer == 0 ? false : true;

	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decode(T)(ref Decoder d, ref T t) if(isSomeString!T)
{
	import std.c.stdlib;
	if(d.token.tag != TokenTag.string) return ErrorCode.wrongType;
	
	char[] data = d.allocator.allocate(d.token.value.length);
	data[] = d.token.value[];
	t = cast(T)data;
	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decode(T : U[], U)(ref Decoder d, ref T t) if(!isSomeString!T)
{
	if(d.token.tag != TokenTag.objectStart) return ErrorCode.wrongType;
	d.nextToken();
	auto app = List!U(d.allocator.track);
	U u = void;
	while(true)
	{
		u = U.init;
		auto err = d.decode!U(u);
		if(err != ErrorCode.none)
			return err;

		app ~= u;
		if(d.token.tag == TokenTag.divider)
			d.nextToken();
		else if(d.token.tag == TokenTag.objectEnd)
			break;
	}

	t = cast(T)app.array;
	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decode(T : U[N], U, size_t N)(ref Decoder d, ref T t)
{
	if(d.token.tag != TokenTag.objectStart) return ErrorCode.wrongType;
	d.nextToken();
	foreach(ref u; t[])
	{
		auto err = d.decode!(U)(u);
		if(err != ErrorCode.none)
			return err;

		if(d.token.tag == TokenTag.divider)
			d.nextToken();
		else if(d.token.tag == TokenTag.objectEnd)
			break;
		else 
			return ErrorCode.wrongType;
	}

	if(d.token.tag != TokenTag.objectEnd) return ErrorCode.bufferOverflow;

	d.nextToken();
	return ErrorCode.none;
}

ErrorCode decodeNamed(T)(ref Decoder d, ref T t) if(is(T == struct))
{
	size_t level = d.parser.level;
outer:
	for(;;d.nextToken())
		retry:
	{
		switch(d.token.tag) with(TokenTag)
		{
			case divider: break;
			case objectEnd: 
				if(level - 1 == d.parser.level)
				{
					d.nextToken();
					return ErrorCode.none;
				}
				else 
				{
					return ErrorCode.unbalancedParens;
				}
			case name: 
				foreach(i, ref field; t.tupleof)
				{
					alias ft  = typeof(field);
					enum name = __traits(identifier, T.tupleof[i]);
					if(d.token.value == name)
					{
						d.nextToken();
						auto err = d.decode!(ft)(field);
						if(err != ErrorCode.none)
							return err;
						goto retry;
					}
				}
				//Gotta skip the member.
				for(;;d.nextToken())
				{
					if(d.token.tag == TokenTag.divider && d.parser.level == level) 
					{
						break;
					}
					else if(d.token.tag == TokenTag.objectEnd && d.parser.level == level - 1)
					{
						goto retry;
					}
				}		
				break;
			default:
				return ErrorCode.unnamed;
		}
	}

	assert(0, "Unreachable");
}

ErrorCode decodeUnnamed(T)(ref Decoder d, ref T t) if(is(T == struct))
{
	foreach(i, ref field; t.tupleof)
	{
		auto res = decode!(typeof(field))(d, field);
		if(res != ErrorCode.none)
			return res;

		if(d.token.tag == TokenTag.divider)
		{
			d.nextToken();
		}
		else if(d.token.tag == TokenTag.objectEnd)
		{
			break;
		}
	}
	ErrorCode res = ErrorCode.none;
	if(d.token.tag != TokenTag.objectEnd)
		res = ErrorCode.toManyFields;
	d.nextToken();
	return res;
}

ErrorCode decode(T)(ref Decoder d, ref T t) if(is(T == struct))
{
	if(d.token.tag != TokenTag.objectStart) return ErrorCode.wrongType;
	d.nextToken();

	if(d.token.tag == TokenTag.name)
		return decodeNamed!T(d, t);
	else 
		return decodeUnnamed!T(d, t);
}

//What is left? 
//1.  numbers   - check
//2.  booleans  - check
//3.  strings   - check
//4.  dynarays  - check
//5.  staarrays - check
//6.  structs   - check
//7.  maps	    - tbi
//8.  lists     - tbi
//9.  alloc     - tbi
//10. ptr       - tbi
//11. converts  - tbi
//12. variant   - tbi
//13. json		- tbi -- json to sidal alt json to sidal tokens.