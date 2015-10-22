//module sidal.serializer;
//
//import std.traits;
//import sidal.parser;
//import allocation;
//import collections.map;
//import util.hash;
//
//enum EncodeMode
//{
//    verbose, //All types are included and all members are named. (within reason, floats, integers, strings and bools are not typed)
//    named,   //Only required types are included. And all members are named.
//    compact, //Member names are not included. And only required types are used.
//}
//
//enum DecodeMode
//{
//    allMember, //The default all values must have a value for each of it's members.
//    optional,  //All members are optional. But extra members not in the struct will casuse error.
//    dynamic,   //All members are optional. Members not in the struct do not cause error. 
//}
//
//alias Encode = bool function(ref SidalDecoder, void* data) @nogc nothrow;
//alias Decode = bool function(ref SidalDecoder, void* data) @nogc nothrow;
//
////Can be overwritten in a particular SidalSerializer range
//__gshared SMap!(TypeHash, Decode, ubyte.max) decoders;
//__gshared SMap!(HashID, Decode, ubyte.max) converters;
//
//
//interface ISidalRange 
//{
//    nothrow:
//    ref SidalToken popFront();
//    ref SidalToken front();
//    bool empty();
//}
//
//class CSidalRange(R) : ISidalRange
//{
//    SidalRange!R r;
//    this(R r)
//    {
//        this.r = SidalRange!R(r);
//    }
//
//nothrow:
//    ref SidalToken popFront()  { r.popFront(); return r.front; }
//    ref SidalToken front() { return r.front; }
//    bool empty() { return r.empty; }
//}
//
//struct SidalDecoder
//{
//    //A buffer value.
//    enum max_inner_range_size = 64;
//    private
//    {
//        struct DummyRange
//        {
//            nothrow:
//            void[max_inner_range_size] store;
//            void popFront() { }
//            bool empty() { return false; }
//            char[] front() { return (char[]).init; }
//        }
//        alias SidalDummy = SidalRange!DummyRange;
//        void[SidalDummy.sizeof] sidal_range_storage;
//    }
//
//    IAllocator allocator;
//    ISidalRange r;
//    alias pf = ref SidalToken delegate() nothrow;
//    pf pfront;
//    SidalToken token;
//
//    this(Range)(Range range, IAllocator allocator = Mallocator.cit)
//    {
//        alias SR = SidalRange!Range;
//        this.allocator = allocator;
//
//        //We want to avoid allocations! (at all costs apperently)
//        static assert(sidal_range_storage.length >= SR.sizeof);
//        this.r = safeEmplace!(CSidalRange!Range)(sidal_range_storage, range);
//        this.pfront = &r.popFront;
//        this.token = r.front;
//    }
//
//nothrow:
//    void popFront() { token = pfront(); }
//
//    T process(T)()
//    {
//        assert(token.tag == TokenTag.type);
//        assert(token.value.array == T.stringof);
//        popFront();
//        assert(token.tag == TokenTag.name);
//        popFront();
//        T t = void;
//        if(make(t))
//            return t;
//        else 
//            assert(false, "An error occured while decoding " ~ T.stringof ~ ".");
//    }
//
//    Decode converter(T)()
//    {
//        enum hash  = HashID(T.stringof);
//        auto h     = HashID(hash, token.value.array);
//        auto d	   = h in converters;
//        assert(d, "No conversion exists between " ~ token.value.array ~ " and " ~ T.stringof ~ ".");
//        return *d;
//    }
//
//    bool make(T)(ref T t)
//    {
//        if(token.tag == TokenTag.type)
//        {
//            if(T.stringof != token.value.array)
//            {
//                auto c = converter!T;
//                popFront();
//                return c(this, &t);
//            }	
//            popFront();
//        }
//
//        return decode!T(this, &t);
//    }
//}
//
//nothrow:
//bool decode(T)(ref SidalDecoder s, T* t) if(isIntegral!T)
//{
//    if(s.token.tag != TokenTag.integer) return false;
//    *t = cast(T)s.token.integer;
//    s.popFront();
//    return true;
//}
//
//T decode(T)(ref SidalDecoder s, T* t) if(isFloatingPoint!T)
//{
//    if(s.token.tag != TokenTag.integer && s.token.tag != TokenTag.floating) 
//        return false;
//
//    if(s.token.tag == TokenTag.integer)
//        *t = cast(T)s.token.integer;
//    else 
//        *t = cast(T)s.token.floating;
//    s.popFront();
//
//    return true;
//}
//
//bool decode(T : U[], U)(ref SidalDecoder s, ref T* data)
//{
//    if(s.token.tag != TokenTag.objectStart) 
//        return false;
//
//    s.popFront();
//    while(true)
//    {
//        U u = void;
//        if(s.make(u))
//            *data = u;
//        else 
//            return false;
//
//        if(s.token.tag == TokenTag.nextMember)
//            continue;
//        else if(s.token.tag == TokenTag.objectEnd)
//            break;
//        else 
//            return false;
//    }
//
//    s.popFront();
//    return true;
//}
//
//bool decode(T : const(char)[N], size_t N)(ref SidalDecoder s, T* data)
//{
//    return serializeString(s, cast(char)[N](*data)[]);
//}
//
//bool decode(T : const(char)[])(ref SidalDecoder s, T* data)
//{
//    return serializeString(s, cast(char[])*data);
//}
//
//bool decode(T : cstring!N, size_t N)(ref SidalDecoder s, ref T* data)
//{
//    data.length = 0;
//    return serializeString(s, *data);
//}
//
//bool serializeString(T)(ref SidalDecoder s, ref T str)
//{
//    while(true)
//    {
//        if(s.token.tag == TokenTag.string)
//            str ~= s.token.value.array;
//        else
//            break;
//
//        s.popFront();
//    }
//
//    return true;
//}
//
//bool decode(T)(ref SidalDecoder s, T* t) if(is(T == struct))
//{
//    if(s.token.tag != TokenTag.objectStart) 
//        return false;
//    s.popFront();
//
//    bool named = false;
//    if(s.token.tag == TokenTag.name)
//        named = true;
//
//    foreach(count; 0 .. T.tupleof.length)
//    {
//        if(named)
//        {
//            foreach(i, ref field; (*t).tupleof)
//            {
//                enum name = __traits(identifier, T.tupleof[i]);
//                if(name == s.token.value.array)
//                {
//                    s.popFront();
//                    if(!s.make(field)) 
//                        return false;
//                    break;
//                }
//            }
//        }
//        else 
//        {
//            foreach(i, ref field; t.tupleof)
//            {
//                if(i == count)
//                {
//                    if(!s.make(field)) 
//                        return false;
//                    break;
//                }
//            }
//        }
//
//        if(count == T.tupleof.length - 1)
//        {
//            if(s.token.tag != TokenTag.objectEnd) 
//                return false;
//        }
//        else 
//        {
//            if(s.token.tag != TokenTag.nextMember) 
//                return false;
//        }
//
//        s.popFront();
//    }
//
//    return true;
//}