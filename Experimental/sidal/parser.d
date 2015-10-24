module sidal.parser;

import std.algorithm;
import std.range : ElementType, isInputRange;
import std.stdio : File;

enum RangeType
{
	file,
	string,
	generic
}

struct GenericRange
{
	alias Empty = bool function(void*) nothrow @nogc;
	alias Fill  = Throwable function(ref GenericRange, void*, ref char[]) nothrow @nogc;
	alias Finalize = void function(void*) nothrow @nogc;

	enum max_data_size = 32;

	void[max_data_size] data_store;
	size_t used;
	Empty rEmpty;
	Fill rFill;
	Finalize rFinalize;

	this(T)(auto ref T t) if(isInputRange!T && is(ElementType!T == char))
	{
		*cast(T*)data_store.ptr = t;
		static Throwable range_fill(T* range, ref char[] toFill)
		{
			if(range.empty) return null;
			try
			{
				foreach(i, ref c; toFill)
				{
					c = range.front;
					range.popFront();
					if(range.empty)
					{
						toFill.length = i + 1;
						break;
					}
				}
			}
			catch(Throwable t)
			{
				return t;
			}

			return null;
		}

		static bool range_empty(T* range) 
		{
			return range.empty;
		}

		static void range_finalize(T* range)
		{
			static if(__traits(compiles, range.__dtor()))
					range.__dtor();

		}	

		rEmpty = cast(Empty)&range_empty;
		rFill  = cast(Fill)&range_fill;
		rFinalize = cast(Finalize)&range_finalize;
	}

	this(T)(auto ref T t) if(isInputRange!T && is(ElementType!T == char[]) && T.sizeof <= max_data_size)
	{
		*cast(T*)data_store.ptr = t;
		static Throwable range_fill(ref GenericRange this_, T* range, ref char[] toFill)
		{
			if(range.empty) return null;
			try
			{
				size_t filled = 0, size = 0;
				do
				{
					size = min(range.front.length - this_.used, toFill.length - filled);
					toFill[filled .. filled + size] = range.front[this_.used .. this_.used + size];
					this_.used   += size;
					filled += size;
					if(this_.used >= range.front.length)
					{
						this_.used = 0;
						range.popFront();
						if(range.empty) 
							break;
					}
				} 
				while(size > 0);
				toFill = toFill[0 .. filled];
			}
			catch(Throwable t)
			{
				return t;
			}
			return null;
		}

		static bool range_empty(T* range)
		{
			return range.empty;
		}

		static void range_finalize(T* range)
		{
			static if(__traits(compiles, range.__dtor()))
			{
				range.__dtor();
			}
		}	


		rEmpty = cast(Empty)&range_empty;
		rFill  = cast(Fill)&range_fill;
		rFinalize = cast(Finalize)&range_finalize;
	}

	void finalize() { return rFinalize(data_store.ptr); }

	nothrow @nogc:
	bool empty() { return rEmpty(data_store.ptr); }
	Throwable fill(ref char[] data) { return rFill(this, data_store.ptr, data); }

}

struct ByChunkRange
{
private:
	File file;
	bool empty;
public:
	this(File f)
	{
		file = f;
		empty = !file.isOpen;
	}

nothrow:
	Throwable finalize()
	{
		try
		{
			file.detach();
		}
		catch(Throwable t)
		{
			return t;
		}

		return null;
	}

	Throwable fill(ref char[] toFill)
	{
		if(empty) return null;
		try
		{
			toFill = file.rawRead(toFill);
			if (toFill.length == 0)
			{
				file.detach();
				empty = true;
			}
		}
		catch(Throwable t)
		{
			return t;
		}

		return null;
	}

}

struct StringRange
{
	private	const(char)[] front;
	private bool inplace;
	
	this(char[] str)
	{
		this.front = str;
		auto p = &str[$ - 1];
		if(*p++ == '\0' || *p == '\0')
			inplace = true;
	}
	
	this(const(char)[] str)
	{
		this.front   = str;
		this.inplace = false;
	}

nothrow:
	bool empty() { return front.length == 0; }
	Throwable fill(ref char[] toFill)
	{
		if(empty) return null;

		if(inplace) 
		{	
			toFill = cast(char[])front;
			front  = front[$ .. $];
			return null;
		}

		size_t size = min(toFill.length, front.length);
		toFill[0 .. size] = front[0 .. size];
		toFill	= toFill[0 .. size];
		front = front[size .. $];

		return null;
	}
}

enum ValueKind
{
	none,
		undecided,
		type,
		divider,
		objectStart,
		objectEnd,
		number,
		string,
		ident,
		name,
		error
}

enum TokenTag : ubyte
{
	type,
	name,
	ident,
	string,
	floating,
	integer,
	objectStart,
	objectEnd,
	itemDivider,
	error
}

struct SidalToken
{
	TokenTag tag;
	union
	{
		char[]	   value;
		double	   floating;
		ulong	   integer;
		size_t	   level;
		Throwable  error;
	}
}

struct SidalRange
{
	enum terminator = '\0';
	RangeType type;
	//Workaround for union. Destructor in file prevents us from using it properly :S
	//union
	//{
	//	ByChunkRange chunk;
	//  StringRange  string;
	//  GenericRange generic
	//}
	void[max(ByChunkRange.sizeof, StringRange.sizeof, GenericRange.sizeof)] range_data;
	void chunk(ref ByChunkRange range) { *(cast(ByChunkRange*)range_data) = range; } 
	void string(ref StringRange range) { *(cast(StringRange*)range_data) = range; }
	void generic(ref GenericRange range) { *cast(GenericRange*)range_data = range; }

	nothrow ByChunkRange* chunk()  { return cast(ByChunkRange*)range_data.ptr; }
	nothrow StringRange*  string() { return cast(StringRange*)range_data.ptr; }
	nothrow GenericRange* generic() { return cast(GenericRange*)range_data.ptr; }

	char[] buffer;
	char*  bptr;
	size_t length;
	bool inplace;

	size_t level, lines, column;
	SidalToken front;
	bool empty;

	this(ByChunkRange range, char[] buffer)
	{
		this.type   = RangeType.file;
		this.chunk  = range;
		this.buffer = buffer;
		this.level = this.length = this.column = 0;
		this.empty = range.empty;
		if(!empty)
		{
			nextBuffer();
			if(front.tag == TokenTag.error)
				throw front.error;

			popFront();
		}
	}

	this(StringRange range, char[] buffer)
	{
		this.type	= RangeType.string;
		this.string = range;
		this.buffer = buffer;
		this.level = this.length = this.column = 0;
		this.empty = range.empty;
		if(!empty)
		{
			nextBuffer();
			if(front.tag == TokenTag.error)
				throw front.error;
			popFront();
		}
	}

	this(GenericRange range, char[] buffer)
	{
		this.type = RangeType.generic;
		this.generic = range;
		this.buffer  = buffer;
		this.level = this.length = this.column = 0;
		this.empty = range.empty;
		if(!empty)
		{
			nextBuffer();
			if(front.tag == TokenTag.error)
				throw front.error;
			popFront();
		}
	}

	~this()
	{
		switch(type)
		{
			case RangeType.file: 
				chunk.finalize();
				break;
			case RangeType.generic:
				generic.finalize();
				break;
			default: break;
		}
	}

nothrow:
	void advance()
	{
		++bptr;
	}

	char bfront() { return *bptr; }
	void popFront()
	{
		parseSuperValue();
	}

	bool getData(size_t size, ref char[] data)
	{
		Throwable t;
		final switch(type)
		{
			case RangeType.file:	 empty = chunk.empty; t = chunk.fill(data);     break;
			case RangeType.string:	 empty = string.empty; t = string.fill(data);   break;
			case RangeType.generic:  empty = generic.empty; t = generic.fill(data); break;
		}

		data.ptr[data.length] = '\0';
		bptr   = data.ptr;
		length = data.length + size;		
		column += length;
		if(t)
		{
			front.tag   = TokenTag.error;
			front.error = t; 
			return empty;
		}

		return !empty;
	}

	bool nextBuffer()
	{
		char[] data	= buffer[0 .. $ - 1];
		return getData(0, data);
	}	

	bool moveBuffer(ref char* start)
	{
		size_t size = length - (start - buffer.ptr);
		import std.c.string;
		memmove(buffer.ptr, start, size);

		char[] data	= buffer[size .. $ - 1];
		bool res = getData(0, data);
		start  = buffer.ptr;
		return res;
	}

	void parseSuperValue()
	{
		int sign = 1;
	outer:	
		for(;;advance()) 
			retry:
		switch(bfront)
		{
			case '\n': 
				lines++; column = 0; 
				goto case;
			case ' ': case '\t': case '\r': break;
			case ',': break;
			case '(':
				front.tag = TokenTag.objectStart;
				front.level = level++;
				advance();
				break outer;
			case ')':
				front.tag = TokenTag.objectEnd;
				front.level = --level;
				advance();
				break outer;
			case ':':
				front.tag = TokenTag.itemDivider;
				front.level = level;
				advance();
				break outer;
			case '"':
				advance();
				parseString(bptr);
				return;
			case '-':
				sign = -1;
				advance();
				goto numberStart;	
			case '+': 
				advance();
				goto numberStart;
			case '0': .. case '9':
			case '.': 
		numberStart:
				return parseNumber(sign);
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '_': 
				//We parse an identifier name or type
				return parseType(bptr);
			case terminator:
				if(nextBuffer)
					goto retry;
				return;		
			default: assert(0);
		}
	}	

	void parseString(char* b)
	{
	stringOuter:
		for(;; advance()) 
		{
		stringRetry:
			switch(bfront)
			{
				case '"': 
					front.tag   = TokenTag.string;
					front.value = b[0 .. bptr - b];
					advance();
					return;
				case terminator:
					if(!moveBuffer(b))
					{
						if(front.tag == TokenTag.error)
							return;
						break stringOuter;
					}
					goto stringRetry;
				default: break;
			}
		}
		makeError();
	}

	void parseHex(int sign)
	{
		ulong value = 0;
		for(;; advance()) 
		{
			if(bfront >= '0' && bfront <= '9')
				value *= 0x10 + bfront - '0';
			else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
				value *= 0x10 + (bfront | 0x20) - 'a';
			else if(bfront == terminator)
			{
				if(!nextBuffer)
				{
					if(front.tag == TokenTag.error)
						return;

					break;
				}
			}	
			else 
				break;
		}

		front.tag	  = TokenTag.integer;
		front.integer = value;
	}

__gshared static double[20] powE = 
	[10e-1, 10e-2, 10e-3, 10e-4, 10e-5, 10e-6, 10e-7, 10e-8, 10e-9, 10e-10,
	 10e-11, 10e-12, 10e-13, 10e-14, 10e-15, 10e-16, 10e-17, 10e-18, 10e-19, 10e-20];

	void parseFloat(int sign, ref ulong value)
	{
		double begin = value, end = void;
		auto start   = bptr;
		auto size    = 0;
		for(;;advance())
		{
			if(bfront >= '0' && bfront <= '9')
				value = value * 10 + bfront - '0';
			else if(bfront == terminator)
			{
				size   = bptr - start;
				if(!nextBuffer)
				{
					start = bptr;
					if(front.tag == TokenTag.error)
						return;
					break;
				}
				start = bptr;
			}
			else
				break;
		}
		end  = value;
		end *= powE[size + bptr - start];
		front.tag = TokenTag.floating;
		front.floating = (begin + end) * sign;
	}	

	import std.c.stdio;
	void parseNumber(int sign)
	{
		ulong value = 0;
		for(;;advance())
		{
			if(bfront >= '0' && bfront <= '9')
				value = value * 10 + bfront - '0';
			else if(bfront == terminator)
			{
				if(!nextBuffer)
				{
					if(front.tag == TokenTag.error)
						return;
					break;
				}
			}
			else
				break;
		}

		switch(bfront)
		{
			default: break;
			case 'x' :  case 'X':
				advance();
				parseHex(sign);
				return;
			case '.':
				advance();
				parseFloat(sign, value);
				return;
		}
		
		front.tag     = TokenTag.integer;
		front.integer = value * sign;
		return;
	}

	//Types: 
	//	ident(([( )*])* / ([( )*ident( )*])*)*
	//Examples: Simple:
	//  float2
	//  float2[ ]
	//  int[ string]
	//  int[ int[ string][]]
	// Examples: hard (look after whitespace label)
	//  float2 [ ]
	//  float2 [ string ] [ ]
	void parseType(char* b)
	{
		size_t lbrackcount, rbrackcount;
typeOuter:
		for(;;advance()) 
typeRetry:			
		switch(bfront)
		{
			case terminator:
				if(!moveBuffer(b))
				{
					if(front.tag == TokenTag.error)
						return;

					break typeOuter;
				}
				else 
					goto typeRetry;
			default:  
				break typeOuter;
			case '\n': lines++; column = 0; goto case;
			case ' ': case '\t': case '\r': 
				break typeOuter;
			case ']':
				rbrackcount++;
				break;
			case '[':
				lbrackcount++;
				break;
			case '0': .. case '9':
			case 'a': .. case 'z': 
			case 'A': .. case 'Z':
			case '_': 								   
				break;
		}

		size_t size = bptr - b;
		if(lbrackcount != rbrackcount)
			goto typeFail;

		lbrackcount = rbrackcount = 0;
		for(;; advance())
		{
		typeRetry2:
			switch(bfront)
			{
				case terminator:
					if(!moveBuffer(b))
					{
						//Last thing in the stream. 
						//It can only be an ident here.
						//If it's not then the stream is wrong anyway!
						front.tag = TokenTag.ident;
						front.value = b[0 .. size];
						return;
					}
					else 
						goto typeRetry2;
				default:
					goto typeFail;
				case '\n': lines++; column = 0; break;
				case ' ': case '\t': case '\r': break;
				case '=':
					front.tag = TokenTag.name;
					front.value = b[0 .. size];
					advance();
					return;
				case ',': case ')':
					front.tag = TokenTag.ident;
					front.value = b[0 .. size];
					return;
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
				case '_': 
				case '(': 
					front.tag = TokenTag.type;
					front.value = b[0 .. size];
					return;
			}
		}
typeFail:
		makeError();
		return;

	}

	void makeError()
	{
		assert(false);
		//front = sidalToken(TokenTag.error, 0);
		front.tag = TokenTag.error;
	}

	@disable this(this);
}