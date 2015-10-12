module experimental.serialization.simple;
import util.traits;
import std.traits;
import std.array;

//This library features simple serialization
//It can only serialize primitives and structures that do not
//have nested structs with indirection. 
//The reason for this is that nested structs with indirections
//requires allocation to deserialize.
//Additionally the serialization is void of type information
//so this will have to be handled by users seperatly instead. 
//For example each serialized message could start with a TypeHash and size to query 
//information about it. 
void serialize(T, Store)(auto ref T t, ref Store s) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
{
	s.put((&t)[0 .. 1]);
}

T deserialize(T, Store)(ref Store s) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
{
	return *cast(T*)(s.take(T.sizeof).ptr);
}

size_t size(T)(auto ref T t) if(!is(T == struct) &&  !isArray!T && !hasIndirections!T)
{
	return T.sizeof;
}	

void serialize(T, Store)(T t, ref Store s) if(isArray!T && !hasIndirections!(ElementType!T))
{
	uint length = cast(uint)t.length;
	s.put((&length)[0 .. 1]);
	s.put(cast(void[])(t));
}

T deserialize(T, Store)(ref Store s) if(isArray!T && !hasIndirections!(ElementType!T))
{
	alias E = ElementType!T;
	uint sz = *cast(uint*)(s.take(uint.sizeof).ptr);
	static if(is(T : E[n], size_t n))
	{
		T t;
		t[0 .. s] = cast(E[])(s.take(sz * E.sizeof));
		return t;
	}
	else
		return cast(T)s.take(sz * E.sizeof);
}

size_t size(T)(auto ref T t) if(isArray!T && !hasIndirections!(ElementType!T))
{
	alias E = ElementType!T;
	return uint.sizeof + E.sizeof * t.length;
}

void serialize(T, Store)(auto ref T t, ref Store s) if(is(T == struct))
{
	foreach(i, ref field; t.tupleof)
	{
		serialize(field, s);		
	}
}

T deserialize(T, Store)(ref Store s) if(is(T == struct))
{
	T t = void;
	foreach(ref field; t.tupleof)
		field = deserialize!(typeof(field))(s);
	return t;
}

size_t size(T)(auto ref T t) if(is(T == struct))
{
	size_t s = 0;
	foreach(ref field; t.tupleof)
		s += size(field);
	return s;
}

enum array_error = "%s cannot be %s as it contains indirections please flatten the structure.";
void serialize(T, Store)(auto ref T t, ref Store s) if(isArray!T && hasIndirections!(ElementType!T))
{
	import std.conv, std.format;
	static assert(false, format(array_error, T.stringof, "serialized"));
}

void deserialize(T, Store)(ref Store s) if(isArray!T && hasIndirections!(ElementType!T))
{
	import std.conv, std.format;
	static assert(false, format(array_error, T.stringof, "deserialized"));
}

size_t size(T)(auto ref T t) if(isArray!T && hasIndirections!(ElementType!T))
{
	import std.conv, std.format;
	static assert(format(array_error, T.stringof, "sized"));
}