////module sidal.serializer;
////
////import std.traits;
////import sidal.parser;
////import allocation;
////import collections.map;
////import util.hash;
////
////enum EncodeMode
////{
////    verbose, //All types are included and all members are named. (within reason, floats, integers, strings and bools are not typed)
////    named,   //Only required types are included. And all members are named.
////    compact, //Member names are not included. And only required types are used.
////}
////
////enum DecodeMode
////{
////    allMember, //The default all values must have a value for each of it's members.
////    optional,  //All members are optional. But extra members not in the struct will casuse error.
////    dynamic,   //All members are optional. Members not in the struct do not cause error. 
////}
////
////alias Encode = bool function(ref SidalDecoder, void* data) @nogc nothrow;
////alias Decode = bool function(ref SidalDecoder, void* data) @nogc nothrow;
////
//////Can be overwritten in a particular SidalSerializer range
////__gshared SMap!(TypeHash, Decode, ubyte.max) decoders;
////__gshared SMap!(HashID, Decode, ubyte.max) converters;
////
////
////interface ISidalRange 
////{
////    nothrow:
////    ref SidalToken popFront();
////    ref SidalToken front();
////    bool empty();
////}
////
////class CSidalRange(R) : ISidalRange
////{
////    SidalRange!R r;
////    this(R r)
////    {
////        this.r = SidalRange!R(r);
////    }
////
////nothrow:
////    ref SidalToken popFront()  { r.popFront(); return r.front; }
////    ref SidalToken front() { return r.front; }
////    bool empty() { return r.empty; }
////}
////
////struct SidalDecoder
////{
////    //A buffer value.
////    enum max_inner_range_size = 64;
////    private
////    {
////        struct DummyRange
////        {
////            nothrow:
////            void[max_inner_range_size] store;
////            void popFront() { }
////            bool empty() { return false; }
////            char[] front() { return (char[]).init; }
////        }
////        alias SidalDummy = SidalRange!DummyRange;
////        void[SidalDummy.sizeof] sidal_range_storage;
////    }
////
////    IAllocator allocator;
////    ISidalRange r;
////    alias pf = ref SidalToken delegate() nothrow;
////    pf pfront;
////    SidalToken token;
////
////    this(Range)(Range range, IAllocator allocator = Mallocator.cit)
////    {
////        alias SR = SidalRange!Range;
////        this.allocator = allocator;
////
////        //We want to avoid allocations! (at all costs apperently)
////        static assert(sidal_range_storage.length >= SR.sizeof);
////        this.r = safeEmplace!(CSidalRange!Range)(sidal_range_storage, range);
////        this.pfront = &r.popFront;
////        this.token = r.front;
////    }
////
////nothrow:
////    void popFront() { token = pfront(); }
////
////    T process(T)()
////    {
////        assert(token.tag == TokenTag.type);
////        assert(token.value.array == T.stringof);
////        popFront();
////        assert(token.tag == TokenTag.name);
////        popFront();
////        T t = void;
////        if(make(t))
////            return t;
////        else 
////            assert(false, "An error occured while decoding " ~ T.stringof ~ ".");
////    }
////
////    Decode converter(T)()
////    {
////        enum hash  = HashID(T.stringof);
////        auto h     = HashID(hash, token.value.array);
////        auto d	   = h in converters;
////        assert(d, "No conversion exists between " ~ token.value.array ~ " and " ~ T.stringof ~ ".");
////        return *d;
////    }
////
////    bool make(T)(ref T t)
////    {
////        if(token.tag == TokenTag.type)
////        {
////            if(T.stringof != token.value.array)
////            {
////                auto c = converter!T;
////                popFront();
////                return c(this, &t);
////            }	
////            popFront();
////        }
////
////        return decode!T(this, &t);
////    }
////}
////
////nothrow:
////bool decode(T)(ref SidalDecoder s, T* t) if(isIntegral!T)
////{
////    if(s.token.tag != TokenTag.integer) return false;
////    *t = cast(T)s.token.integer;
////    s.popFront();
////    return true;
////}
////
////T decode(T)(ref SidalDecoder s, T* t) if(isFloatingPoint!T)
////{
////    if(s.token.tag != TokenTag.integer && s.token.tag != TokenTag.floating) 
////        return false;
////
////    if(s.token.tag == TokenTag.integer)
////        *t = cast(T)s.token.integer;
////    else 
////        *t = cast(T)s.token.floating;
////    s.popFront();
////
////    return true;
////}
////
////bool decode(T : U[], U)(ref SidalDecoder s, ref T* data)
////{
////    if(s.token.tag != TokenTag.objectStart) 
////        return false;
////
////    s.popFront();
////    while(true)
////    {
////        U u = void;
////        if(s.make(u))
////            *data = u;
////        else 
////            return false;
////
////        if(s.token.tag == TokenTag.nextMember)
////            continue;
////        else if(s.token.tag == TokenTag.objectEnd)
////            break;
////        else 
////            return false;
////    }
////
////    s.popFront();
////    return true;
////}
////
////bool decode(T : const(char)[N], size_t N)(ref SidalDecoder s, T* data)
////{
////    return serializeString(s, cast(char)[N](*data)[]);
////}
////
////bool decode(T : const(char)[])(ref SidalDecoder s, T* data)
////{
////    return serializeString(s, cast(char[])*data);
////}
////
////bool decode(T : cstring!N, size_t N)(ref SidalDecoder s, ref T* data)
////{
////    data.length = 0;
////    return serializeString(s, *data);
////}
////
////bool serializeString(T)(ref SidalDecoder s, ref T str)
////{
////    while(true)
////    {
////        if(s.token.tag == TokenTag.string)
////            str ~= s.token.value.array;
////        else
////            break;
////
////        s.popFront();
////    }
////
////    return true;
////}
////
////bool decode(T)(ref SidalDecoder s, T* t) if(is(T == struct))
////{
////    if(s.token.tag != TokenTag.objectStart) 
////        return false;
////    s.popFront();
////
////    immutable named = s.token.tag == TokenTag.name;
////    foreach(count; 0 .. T.tupleof.length)
////    {
////        if(named)
////        {
////            foreach(i, ref field; (*t).tupleof)
////            {
////                enum name = __traits(identifier, T.tupleof[i]);
////                if(name == s.token.value)
////                {
////                    s.popFront();
////                    if(!s.make(field)) 
////                        return false;
////                    break;
////                }
////            }
////        }
////        else 
////        {
////            foreach(i, ref field; t.tupleof)
////            {
////                if(i == count)
////                {
////                    if(!s.make(field)) 
////                        return false;
////                    break;
////                }
////            }
////        }
////
////        if(count == T.tupleof.length - 1)
////        {
////            if(s.token.tag != TokenTag.objectEnd) 
////                return false;
////        }
////        else 
////        {
////            if(s.token.tag != TokenTag.nextMember) 
////                return false;
////        }
////
////        s.popFront();
////    }
////
////    return true;
////}
//module sidal.parser;
//
//import std.algorithm;
//import std.range : ElementType, isInputRange;
//import std.stdio : File;
//
//enum RangeType
//{
//    file,
//    string,
//    generic
//}
//
//struct GenericRange
//{
//    alias Empty = bool function(void*) nothrow @nogc;
//    alias Fill  = Throwable function(ref GenericRange, void*, ref char[]) nothrow @nogc;
//    alias Finalize = void function(void*) nothrow @nogc;
//
//    enum max_data_size = 32;
//
//    void[max_data_size] data_store;
//    size_t used;
//    Empty rEmpty;
//    Fill rFill;
//    Finalize rFinalize;
//
//    this(T)(auto ref T t) if(isInputRange!T && is(ElementType!T == char))
//    {
//        *cast(T*)data_store.ptr = t;
//        static Throwable range_fill(T* range, ref char[] toFill)
//        {
//            if(range.empty) return null;
//            try
//            {
//                foreach(i, ref c; toFill)
//                {
//                    c = range.front;
//                    range.popFront();
//                    if(range.empty)
//                    {
//                        toFill.length = i + 1;
//                        break;
//                    }
//                }
//            }
//            catch(Throwable t)
//            {
//                return t;
//            }
//
//            return null;
//        }
//
//        static bool range_empty(T* range) 
//        {
//            return range.empty;
//        }
//
//        static void range_finalize(T* range)
//        {
//            static if(__traits(compiles, range.__dtor()))
//                range.__dtor();
//
//        }	
//
//        rEmpty = cast(Empty)&range_empty;
//        rFill  = cast(Fill)&range_fill;
//        rFinalize = cast(Finalize)&range_finalize;
//    }
//
//    this(T)(auto ref T t) if(isInputRange!T && is(ElementType!T == char[]) && T.sizeof <= max_data_size)
//    {
//        *cast(T*)data_store.ptr = t;
//        static Throwable range_fill(ref GenericRange this_, T* range, ref char[] toFill)
//        {
//            if(range.empty) return null;
//            try
//            {
//                size_t filled = 0, size = 0;
//                do
//                {
//                    size = min(range.front.length - this_.used, toFill.length - filled);
//                    toFill[filled .. filled + size] = range.front[this_.used .. this_.used + size];
//                    this_.used   += size;
//                    filled += size;
//                    if(this_.used >= range.front.length)
//                    {
//                        this_.used = 0;
//                        range.popFront();
//                        if(range.empty) 
//                            break;
//                    }
//                } 
//                while(size > 0);
//                toFill = toFill[0 .. filled];
//            }
//            catch(Throwable t)
//            {
//                return t;
//            }
//            return null;
//        }
//
//        static bool range_empty(T* range)
//        {
//            return range.empty;
//        }
//
//        static void range_finalize(T* range)
//        {
//            static if(__traits(compiles, range.__dtor()))
//            {
//                range.__dtor();
//            }
//        }	
//
//
//        rEmpty = cast(Empty)&range_empty;
//        rFill  = cast(Fill)&range_fill;
//        rFinalize = cast(Finalize)&range_finalize;
//    }
//
//    void finalize() { return rFinalize(data_store.ptr); }
//
//    nothrow @nogc:
//    bool empty() { return rEmpty(data_store.ptr); }
//    Throwable fill(ref char[] data) { return rFill(this, data_store.ptr, data); }
//
//}
//
//struct ByChunkRange
//{
//private:
//    File file;
//    bool empty;
//public:
//    this(File f)
//    {
//        file = f;
//        empty = !file.isOpen;
//    }
//
//nothrow:
//    Throwable finalize()
//{
//    try
//    {
//        file.detach();
//    }
//    catch(Throwable t)
//    {
//        return t;
//    }
//
//    return null;
//}
//
//    Throwable fill(ref char[] toFill)
//    {
//        if(empty) return null;
//        try
//        {
//            toFill = file.rawRead(toFill);
//            if (toFill.length == 0)
//            {
//                file.detach();
//                empty = true;
//            }
//        }
//        catch(Throwable t)
//        {
//            return t;
//        }
//
//        return null;
//    }
//
//}
//
//struct StringRange
//{
//    private	const(char)[] front;
//    private bool inplace;
//
//    this(char[] str)
//    {
//        this.front = str;
//        auto p = &str[$ - 1];
//        if(*p++ == '\0' || *p == '\0')
//            inplace = true;
//    }
//
//    this(const(char)[] str)
//    {
//        this.front   = str;
//        this.inplace = false;
//    }
//
//nothrow:
//    bool empty() { return front.length == 0; }
//    Throwable fill(ref char[] toFill)
//    {
//        if(empty) return null;
//
//        if(inplace) 
//        {	
//            toFill = cast(char[])front;
//            front  = front[$ .. $];
//            return null;
//        }
//
//        size_t size = min(toFill.length, front.length);
//        toFill[0 .. size] = front[0 .. size];
//        toFill	= toFill[0 .. size];
//        front = front[size .. $];
//
//        return null;
//    }
//}
//
//enum ValueKind
//{
//    none,
//    undecided,
//    type,
//    divider,
//    objectStart,
//    objectEnd,
//    number,
//    string,
//    ident,
//    name,
//    error
//}
//
//enum TokenTag : ubyte
//{
//    type,
//    name,
//    ident,
//    string,
//    floating,
//    integer,
//    objectStart,
//    objectEnd,
//    itemDivider,
//    error
//}
//
//struct SidalToken
//{
//    TokenTag tag;
//    union
//    {
//        char[]	   value;
//        double	   floating;
//        ulong	   integer;
//        size_t	   level;
//        Throwable  error;
//    }
//}
//
//struct SidalRange
//{
//    enum terminator = '\0';
//    RangeType type;
//    //Workaround for union. Destructor in file prevents us from using it properly :S
//    //union
//    //{
//    //	ByChunkRange chunk;
//    //  StringRange  string;
//    //  GenericRange generic
//    //}
//    void[max(ByChunkRange.sizeof, StringRange.sizeof, GenericRange.sizeof)] range_data;
//    void chunk(ref ByChunkRange range) { *(cast(ByChunkRange*)range_data) = range; } 
//    void string(ref StringRange range) { *(cast(StringRange*)range_data) = range; }
//    void generic(ref GenericRange range) { *cast(GenericRange*)range_data = range; }
//
//    nothrow ByChunkRange* chunk()  { return cast(ByChunkRange*)range_data.ptr; }
//    nothrow StringRange*  string() { return cast(StringRange*)range_data.ptr; }
//    nothrow GenericRange* generic() { return cast(GenericRange*)range_data.ptr; }
//
//    char[] buffer;
//    char*  bptr;
//    size_t length;
//    bool inplace;
//
//    size_t level, lines, column;
//    SidalToken front;
//    bool empty;
//
//    this(ByChunkRange range, char[] buffer)
//    {
//        this.type   = RangeType.file;
//        this.chunk  = range;
//        this.buffer = buffer;
//        this.level = this.length = this.column = 0;
//        this.empty = range.empty;
//        if(!empty)
//        {
//            nextBuffer();
//            if(front.tag == TokenTag.error)
//                throw front.error;
//
//            popFront();
//        }
//    }
//
//    this(StringRange range, char[] buffer)
//    {
//        this.type	= RangeType.string;
//        this.string = range;
//        this.buffer = buffer;
//        this.level = this.length = this.column = 0;
//        this.empty = range.empty;
//        if(!empty)
//        {
//            nextBuffer();
//            if(front.tag == TokenTag.error)
//                throw front.error;
//            popFront();
//        }
//    }
//
//    this(GenericRange range, char[] buffer)
//    {
//        this.type = RangeType.generic;
//        this.generic = range;
//        this.buffer  = buffer;
//        this.level = this.length = this.column = 0;
//        this.empty = range.empty;
//        if(!empty)
//        {
//            nextBuffer();
//            if(front.tag == TokenTag.error)
//                throw front.error;
//            popFront();
//        }
//    }
//
//    ~this()
//    {
//        switch(type)
//        {
//            case RangeType.file: 
//                chunk.finalize();
//                break;
//            case RangeType.generic:
//                generic.finalize();
//                break;
//            default: break;
//        }
//    }
//
//nothrow:
//    void advance()
//    {
//        ++bptr;
//    }
//
//    char bfront() { return *bptr; }
//    void popFront()
//    {
//        parseSuperValue();
//    }
//
//    bool getData(size_t size, ref char[] data)
//    {
//        Throwable t;
//        final switch(type)
//        {
//            case RangeType.file:	 empty = chunk.empty; t = chunk.fill(data);     break;
//            case RangeType.string:	 empty = string.empty; t = string.fill(data);   break;
//            case RangeType.generic:  empty = generic.empty; t = generic.fill(data); break;
//        }
//
//        data.ptr[data.length] = '\0';
//        bptr   = data.ptr;
//        length = data.length + size;		
//        column += length;
//        if(t)
//        {
//            front.tag   = TokenTag.error;
//            front.error = t; 
//            return empty;
//        }
//
//        return !empty;
//    }
//
//    bool nextBuffer()
//    {
//        char[] data	= buffer[0 .. $ - 1];
//        return getData(0, data);
//    }	
//
//    bool moveBuffer(ref char* start)
//    {
//        size_t size = length - (start - buffer.ptr);
//        import std.c.string;
//        memmove(buffer.ptr, start, size);
//
//        char[] data	= buffer[size .. $ - 1];
//        bool res = getData(0, data);
//        start  = buffer.ptr;
//        return res;
//    }
//
//    void parseSuperValue()
//    {
//        int sign = 1;
//    outer:	
//        for(;;advance()) 
//            retry:
//        switch(bfront)
//        {
//            case '\n': 
//                lines++; column = 0; 
//                goto case;
//            case ' ': case '\t': case '\r': break;
//            case ',': break;
//            case '(':
//                front.tag = TokenTag.objectStart;
//                front.level = level++;
//                advance();
//                break outer;
//            case ')':
//                front.tag = TokenTag.objectEnd;
//                front.level = --level;
//                advance();
//                break outer;
//            case ':':
//                front.tag = TokenTag.itemDivider;
//                front.level = level;
//                advance();
//                break outer;
//            case '"':
//                advance();
//                //parseString(bptr);
//                //Function overhead visible in profiler
//                //So we inline.
//                char* b = bptr;
//            stringOuter:
//                for(;; advance()) 
//                {
//                stringRetry:
//                    switch(bfront)
//                    {
//                        case '"': 
//                            front.tag   = TokenTag.string;
//                            front.value = b[0 .. bptr - b];
//                            advance();
//                            return;
//                        case terminator:
//                            if(!moveBuffer(b))
//                            {
//                                if(front.tag == TokenTag.error)
//                                    return;
//                                break stringOuter;
//                            }
//                            goto stringRetry;
//                        default: break;
//                    }
//                }
//                makeError();
//                return;
//            case '-':
//                sign = -1;
//                advance();
//                goto numberStart;	
//            case '+': 
//                advance();
//                goto numberStart;
//            case '0': .. case '9':
//            case '.': 
//            numberStart:
//                //return parseNumber(sign);
//                //Inlining it for profit.
//                ulong value = 0;
//                for(;;advance())
//                {
//                    if(bfront >= '0' && bfront <= '9')
//                        value = value * 10 + bfront - '0';
//                    else if(bfront == terminator)
//                    {
//                        if(!nextBuffer)
//                        {
//                            if(front.tag == TokenTag.error)
//                                return;
//                            break;
//                        }
//                    }
//                    else
//                        break;
//                }
//
//                switch(bfront)
//                {
//                    default: break;
//                    case 'x' :  case 'X':
//                        advance();
//                        //parseHex(sign);
//                        value = 0;
//                        for(;; advance()) 
//                        {
//                            if(bfront >= '0' && bfront <= '9')
//                                value *= 0x10 + bfront - '0';
//                            else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
//                                value *= 0x10 + (bfront | 0x20) - 'a';
//                            else if(bfront == terminator)
//                            {
//                                if(!nextBuffer)
//                                {
//                                    if(front.tag == TokenTag.error)
//                                        return;
//
//                                    break;
//                                }
//                            }	
//                            else 
//                                break;
//                        }
//
//                        front.tag	  = TokenTag.integer;
//                        front.integer = value;
//                        return;
//                    case '.':
//                        advance();
//                        //parseFloat(sign, value);
//                        double begin = value, end = void;
//                        auto start   = bptr;
//                        auto size    = 0;
//                        for(;;advance())
//                        {
//                            if(bfront >= '0' && bfront <= '9')
//                                value = value * 10 + bfront - '0';
//                            else if(bfront == terminator)
//                            {
//                                size   = bptr - start;
//                                if(!nextBuffer)
//                                {
//                                    if(front.tag == TokenTag.error)
//                                        return;
//                                    break;
//                                }
//                                start = bptr;
//                            }
//                            else
//                                break;
//                        }
//                        end  = value;
//                        end *= powE[size + bptr - start];
//                        front.tag = TokenTag.floating;
//                        front.floating = (begin + end) * sign;
//                        return;
//                }
//
//                front.tag     = TokenTag.integer;
//                front.integer = value * sign;
//                return;
//            case 'a': .. case 'z':
//            case 'A': .. case 'Z':
//            case '_': 
//                //We parse an identifier name or type
//                //return parseType(bptr);
//                char* b = bptr;
//                size_t lbrackcount, rbrackcount;
//            typeOuter:
//                for(;;advance()) 
//                    typeRetry:			
//                switch(bfront)
//                {
//                    case terminator:
//                        if(!moveBuffer(b))
//                        {
//                            break typeOuter;
//                        }
//                        else 
//                            goto typeRetry;
//                    default:  
//                        break typeOuter;
//                    case '\n': lines++; column = 0; goto case;
//                    case ' ': case '\t': case '\r': 
//                        break typeOuter;
//                    case ']':
//                        rbrackcount++;
//                        break;
//                    case '[':
//                        lbrackcount++;
//                        break;
//                    case '0': .. case '9':
//                    case 'a': .. case 'z': 
//                    case 'A': .. case 'Z':
//                    case '_': 								   
//                        break;
//                }
//
//                size_t size = bptr - b;
//                if(lbrackcount != rbrackcount)
//                    goto typeFail;
//
//                lbrackcount = rbrackcount = 0;
//                for(;; advance())
//                {
//                typeRetry2:
//                    switch(bfront)
//                    {
//                        case terminator:
//                            if(!moveBuffer(b))
//                            {
//                                if(front.tag == TokenTag.error)
//                                    return;
//
//                                //Last thing in the stream. 
//                                //It can only be an ident here.
//                                //If it's not then the stream is wrong anyway!
//                                front.tag = TokenTag.ident;
//                                front.value = b[0 .. size];
//                                return;
//                            }
//                            else 
//                                goto typeRetry2;
//                        default:
//                            goto typeFail;
//                        case '\n': lines++; column = 0; break;
//                        case ' ': case '\t': case '\r': break;
//                        case '=':
//                            front.tag = TokenTag.name;
//                            front.value = b[0 .. size];
//                            advance();
//                            return;
//                        case ',': case ')':
//                            front.tag = TokenTag.ident;
//                            front.value = b[0 .. size];
//                            return;
//                        case 'a': .. case 'z':
//                        case 'A': .. case 'Z':
//                        case '_': 
//                        case '(': 
//                            front.tag = TokenTag.type;
//                            front.value = b[0 .. size];
//                            return;
//                    }
//                }
//            typeFail:
//                makeError();
//                return;
//            case terminator:
//                if(nextBuffer)
//                    goto retry;
//                return;		
//            default: assert(0);
//        }
//    }	
//
//    void parseString(char* b)
//    {
//    stringOuter:
//        for(;; advance()) 
//        {
//        stringRetry:
//            switch(bfront)
//            {
//                case '"': 
//                    front.tag   = TokenTag.string;
//                    front.value = b[0 .. bptr - b];
//                    advance();
//                    return;
//                case terminator:
//                    if(!moveBuffer(b))
//                    {
//                        if(front.tag == TokenTag.error)
//                            return;
//                        break stringOuter;
//                    }
//                    goto stringRetry;
//                default: break;
//            }
//        }
//        makeError();
//    }
//
//    void parseHex(int sign)
//    {
//        ulong value = 0;
//        for(;; advance()) 
//        {
//            if(bfront >= '0' && bfront <= '9')
//                value *= 0x10 + bfront - '0';
//            else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
//                value *= 0x10 + (bfront | 0x20) - 'a';
//            else if(bfront == terminator)
//            {
//                if(!nextBuffer)
//                {
//                    if(front.tag == TokenTag.error)
//                        return;
//
//                    break;
//                }
//            }	
//            else 
//                break;
//        }
//
//        front.tag	  = TokenTag.integer;
//        front.integer = value;
//    }
//
//    __gshared static double[20] powE = 
//    [10e-1, 10e-2, 10e-3, 10e-4, 10e-5, 10e-6, 10e-7, 10e-8, 10e-9, 10e-10,
//    10e-11, 10e-12, 10e-13, 10e-14, 10e-15, 10e-16, 10e-17, 10e-18, 10e-19, 10e-20];
//
//    void parseFloat(int sign, ref ulong value)
//    {
//        double begin = value, end = void;
//        auto start   = bptr;
//        auto size    = 0;
//        for(;;advance())
//        {
//            if(bfront >= '0' && bfront <= '9')
//                value = value * 10 + bfront - '0';
//            else if(bfront == terminator)
//            {
//                size   = bptr - start;
//                if(!nextBuffer)
//                {
//                    start = bptr;
//                    if(front.tag == TokenTag.error)
//                        return;
//                    break;
//                }
//                start = bptr;
//            }
//            else
//                break;
//        }
//        end  = value;
//        end *= powE[size + bptr - start];
//        front.tag = TokenTag.floating;
//        front.floating = (begin + end) * sign;
//    }	
//
//    import std.c.stdio;
//    void parseNumber(int sign)
//    {
//        ulong value = 0;
//        for(;;advance())
//        {
//            if(bfront >= '0' && bfront <= '9')
//                value = value * 10 + bfront - '0';
//            else if(bfront == terminator)
//            {
//                if(!nextBuffer)
//                {
//                    if(front.tag == TokenTag.error)
//                        return;
//                    break;
//                }
//            }
//            else
//                break;
//        }
//
//        switch(bfront)
//        {
//            default: break;
//            case 'x' :  case 'X':
//                advance();
//                //parseHex(sign);
//                value = 0;
//                for(;; advance()) 
//                {
//                    if(bfront >= '0' && bfront <= '9')
//                        value *= 0x10 + bfront - '0';
//                    else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
//                        value *= 0x10 + (bfront | 0x20) - 'a';
//                    else if(bfront == terminator)
//                    {
//                        if(!nextBuffer)
//                        {
//                            if(front.tag == TokenTag.error)
//                                return;
//                            break;
//                        }
//                    }	
//                    else 
//                        break;
//                }
//
//                front.tag	  = TokenTag.integer;
//                front.integer = value;
//                return;
//            case '.':
//                advance();
//                //parseFloat(sign, value);
//                double begin = value, end = void;
//                auto start   = bptr;
//                auto size    = 0;
//                for(;;advance())
//                {
//                    if(bfront >= '0' && bfront <= '9')
//                        value = value * 10 + bfront - '0';
//                    else if(bfront == terminator)
//                    {
//                        size   = bptr - start;
//                        if(!nextBuffer)
//                        {
//                            start = bptr;
//                            if(front.tag == TokenTag.error)
//                                return;
//                            break;
//                        }
//                        start = bptr;
//                    }
//                    else
//                        break;
//                }
//                end  = value;
//                end *= powE[size + bptr - start];
//                front.tag = TokenTag.floating;
//                front.floating = (begin + end) * sign;
//                return;
//        }
//
//        front.tag     = TokenTag.integer;
//        front.integer = value * sign;
//        return;
//    }
//
//    //Types: 
//    //	ident(([( )*])* / ([( )*ident( )*])*)*
//    //Examples: Simple:
//    //  float2
//    //  float2[ ]
//    //  int[ string]
//    //  int[ int[ string][]]
//    // Examples: hard (look after whitespace label)
//    //  float2 [ ]
//    //  float2 [ string ] [ ]
//    void parseType(char* b)
//    {
//        size_t lbrackcount, rbrackcount;
//    typeOuter:
//        for(;;advance()) 
//            typeRetry:			
//        switch(bfront)
//        {
//            case terminator:
//                if(!moveBuffer(b))
//                {
//                    if(front.tag == TokenTag.error)
//                        return;
//
//                    break typeOuter;
//                }
//                else 
//                    goto typeRetry;
//            default:  
//                break typeOuter;
//            case '\n': lines++; column = 0; goto case;
//            case ' ': case '\t': case '\r': 
//                break typeOuter;
//            case ']':
//                rbrackcount++;
//                break;
//            case '[':
//                lbrackcount++;
//                break;
//            case '0': .. case '9':
//            case 'a': .. case 'z': 
//            case 'A': .. case 'Z':
//            case '_': 								   
//                break;
//        }
//
//        size_t size = bptr - b;
//        if(lbrackcount != rbrackcount)
//            goto typeFail;
//
//        lbrackcount = rbrackcount = 0;
//        for(;; advance())
//        {
//        typeRetry2:
//            switch(bfront)
//            {
//                case terminator:
//                    if(!moveBuffer(b))
//                    {
//                        //Last thing in the stream. 
//                        //It can only be an ident here.
//                        //If it's not then the stream is wrong anyway!
//                        front.tag = TokenTag.ident;
//                        front.value = b[0 .. size];
//                        return;
//                    }
//                    else 
//                        goto typeRetry2;
//                default:
//                    goto typeFail;
//                case '\n': lines++; column = 0; break;
//                case ' ': case '\t': case '\r': break;
//                case '=':
//                    front.tag = TokenTag.name;
//                    front.value = b[0 .. size];
//                    advance();
//                    return;
//                case ',': case ')':
//                    front.tag = TokenTag.ident;
//                    front.value = b[0 .. size];
//                    return;
//                case 'a': .. case 'z':
//                case 'A': .. case 'Z':
//                case '_': 
//                case '(': 
//                    front.tag = TokenTag.type;
//                    front.value = b[0 .. size];
//                    return;
//            }
//        }
//    typeFail:
//        makeError();
//        return;
//
//    }
//
//    void makeError()
//    {
//        assert(false);
//        //front = sidalToken(TokenTag.error, 0);
//        front.tag = TokenTag.error;
//    }
//
//    @disable this(this);
//}