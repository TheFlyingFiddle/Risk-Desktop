module encoding.binary;
import util.traits;
import allocation : IAllocator, Mallocator;

@trusted:
void encode(T,S)(ref S s, auto ref T t) if(!hasIndirections!T)
{
	void[] data = (&T)[0 .. 1];
	s.put(data);
}


void encode(T, S)(ref S s, auto ref T t)  if(hasIndirections!T && is(T == struct))
{
	void[] data = (&t)[0 .. 1];
	s.put(data); //First we put the data we have. 
	encodeInner!(T, S)(s, t);
}

void encode(T : U[], U, S)(ref S s, T t)
{
	size_t len = t.length;
	size_t ptr = cast(size_t)t.ptr;
	void[] data = (&len)[0 .. 2];
	s.put(data);
	encodeInner(s, t);
}

void encode(T : U*, U, S)(ref S s, auto ref T t, size_t length = 1)
{
	size_t s = cast(size_t)t;
	s.put((&s)[0 .. 1]);
	s.encodeInner(t, length);
}

void encodeInner(T : U*, U, S)(ref S s, auto ref T t, size_t length = 1) if(!hasIndirections!U)
{
	void[] data = t[0 .. length];
	s.put(data);
}

void encodeInner(T : U*, U, S)(ref S s, auto ref T t, size_t length = 1) if(hasIndirections!U)
{
	void[] data = t[0 .. length];
	s.put(data);
	foreach(ref e; t[0 .. length])
		s.encodeInner(e);
}

void encodeInner(T, S)(ref S s, auto ref T t) if(is(T == IAllocator))
{
	//No operations don't want to serialize allocator. 
}

void encodeInner(T, S)(ref S s, auto ref T t) if(hasIndirections!T && is(T == struct))
{
	foreach(i, ref field; t.tupleof)
	{
		alias ft = typeof(field);
		static if(hasIndirections!ft)
		{
			static if(is(ft : U*, U))
			{
				//Don't want to encode stuff if the pointer is null. 
				if(field is null) continue;

				alias attribs = AliasSeq!(__traits(getAttributes, T.tupleof[i]));
				static if(attribs.length > 0)
				{
					static if(is(typeof(attribs[0]) == string))	
					{
						enum variable = attribs[0];
						mixin("size_t length = t." ~ variable ~ ";");
					}
					else static if(true)
					{
						size_t length = attribs[0](t);
					}
					else static assert(0, "...");
				}
				else 
				{
					size_t length = 1;
				}

				s.encodeInner(field, length);
			}
			else 
			{
				s.encodeInner(field);		
			}
		}
	}
}

void encodeInner(T : U[], U, S)(ref S s, auto ref T t) if(!hasIndirections!U)
{
	void[] data = cast(void[])t;
	s.put(data);
}

void encodeInner(T : U[], U, S)(ref S s, auto ref T t) if(hasIndirections!U)
{
	s.put(cast(void[])t);
	foreach(ref elem; t)
		s.encodeInner(elem);
}

void decode(T)(void* data, auto ref T t) if(!hasIndirections!T && is(T == struct))
{
	t = *cast(T*)data.ptr;
}

void decode(T)(void* start, ref T t) if(hasIndirections!T && is(T == struct))
{
	//Pointer patching goodness. 
	t = *cast(T*)start;
    decodeInner!(T)(start + T.sizeof, t);
}

void decode(T : U[], U)(void* start, ref T t) if(hasIndirections!U)
{
	size_t[2] size_ptr = *cast(size_t[2]*)start;
	size_t offset = size_t[2].sizeof;
	t = cast(T)start[offset .. offset + size_ptr[0] * U.sizeof];
	decodeInner(start + offset, t);
}

void decode(T : U[], U)(void* start, ref T t) if(!hasIndirections!U)
{
	size_t[2] size_ptr = *cast(size_t[2]*)start;
	size_t offset = size_t[2].sizeof;
	t = cast(T)start[offset .. offset + size_ptr[0] * U.sizeof];
}

size_t decodeInner(T)(void* start, ref T t) if(is(T == IAllocator))
{
	t = Mallocator.cit; //Defaults to Mallocator.cit could do something else but I think this is good enough!.
	return 0;
}

size_t decodeInner(T : U*, U)(void* start, ref T t, size_t length = 1) if(!hasIndirections!U)
{
	t = cast(T)start;
	return U.sizeof * length;
}

size_t decodeInner(T : U*, U)(void* start, ref T t, size_t length = 1) if(hasIndirections!U)
{
	t = cast(T)start;
	size_t offset = U.sizeof * length;
	foreach(ref e; t[0 .. length])
		offset += decodeInner(start + offset, e);
	return offset;
}

size_t decodeInner(T)(void* start, ref T t) if(hasIndirections!T && is(T == struct))
{
	size_t offset = 0;
	foreach(i, ref field; t.tupleof)
	{
		alias ft = typeof(field);
		static if(hasIndirections!(typeof(field)))
		{
			static if(is(ft : U*, U))
			{
				//Don't want to decode stuff incase the pointer is null. 
				if(field is null) continue;

				alias attribs = AliasSeq!(__traits(getAttributes, T.tupleof[i]));
				static if(attribs.length > 0)
				{
					static if(is(typeof(attribs[0]) == string))	
					{
						enum variable = attribs[0];
						mixin("size_t length = t." ~ variable ~ ";");
					}
					else static if(true)
					{
						size_t length = attribs[0](t);
					}
					else static assert(0, "...");
				}
				else 
				{
					size_t length = 1;
				}

				offset += decodeInner(start + offset, field, length);
			}
			else 
			{
				offset += decodeInner(start + offset, field);		
			}
		}
	}

	return offset;
}

size_t decodeInner(T : U[], U)(void* start, ref  T t) if(!hasIndirections!U)
{
	t = (cast(U*)start)[0 .. t.length];
	return U.sizeof * t.length;
}

size_t decodeInner(T : U[], U)(void* start, ref T t) if(hasIndirections!U)
{
	t = (cast(U*)start)[0 .. t.length];
	size_t offset = U.sizeof * t.length;
	foreach(ref elem; t)
	{
		offset += decodeInner(start + offset, elem);
	}
	return offset;
}

struct Test
{
	int a = 1;
	int b = 2;
	string c = "hello";
	string[][] d = [["apa", "bapa", "capa", "maka" ], ["mowgli", "powgli", "trololololo"]];
}

struct Test2
{
	int a = 1, b = 3;
	float k = 23.32f;
	string name = "okokok";
	Test[] t = [Test.init, Test.init, Test.init, Test.init];
}

struct Test3
{
	int a; 
	Test* test;
}

struct TestStore
{	
	ubyte[] data;
	void put(void[] d) pure nothrow @safe
	{
		data ~= cast(ubyte[])d;
	}
}

unittest
{
	auto store = TestStore();
	auto test  = Test2();
	store.encode(test);
	Test2 res = void;
	decode(store.data.ptr, res);
	assert(test == res);
}

unittest
{
	auto store = TestStore();
	store.encode("hello");
	string s;
	decode(store.data.ptr, s);
	assert(s == "hello");
}

unittest
{
	auto store = TestStore();
	store.encode(["hi", "i" , "am"]);
	string[] s2;
	decode(store.data.ptr, s2);
	assert(s2 == ["hi", "i", "am"]);
}

unittest
{
	auto store = TestStore();
	Test t;
	auto test3 = Test3(20, &t);
	store.encode(test3);
	Test3 res3;
	decode(store.data.ptr, res3);

	assert(res3.a == test3.a, "Test variable a is not the same");
	assert(*res3.test == *test3.test);
}

unittest
{
	auto store = TestStore();
	uint[5] dat = [1, 20, 32, 51, 25];
	import collections.list;
	auto list = FixedList!uint(dat.ptr, 5, 5);
	store.encode(list);
	FixedList!uint list2;
	decode(store.data.ptr, list2);
}

unittest
{
	import collections.list;
	auto store = TestStore();
	auto list  = List!uint(Mallocator.cit, 5);
	list ~= 1; list ~= 2; list ~= 3;
	list ~= 4; list ~= 5; list ~= 6;
	
	store.encode(list);
	List!uint res;
	decode(store.data.ptr, res);
}

unittest
{
	import collections.map;
	auto store = TestStore();
	auto map = Map!(string, int)(Mallocator.cit, 2);
	map.add("Hello", 1);
	map.add("World", 2);
	map.add("Wohooo", 123);
	import std.stdio;
	writeln(map.rep.indices[0 .. 4]);
	writeln(map.rep.elements[0 .. 2]);


	store.encode(map);
	Map!(string, int) res;
	decode(store.data.ptr, res);
	
	writeln(res.rep.indices[0 .. 4]);
	writeln(res.rep.elements[0 .. 2]);

	assert(map == res);
}

//Binary would be: 
//[int | int | length | ptr | string_value ]

