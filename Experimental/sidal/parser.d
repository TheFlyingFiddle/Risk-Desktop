module sidal.parser;

import std.ascii;
import std.variant;
import collections.list;
import std.algorithm;
import std.range : ElementType;
import std.stdio : File;

enum RangeType
{
	file,
	string
}

struct RangeError
{
	Throwable t;
}


struct ByChunkRange
{
private:
	File file;
public:
	this(File f)
	{
		file = f;
	}

nothrow:
	bool empty()   { return file.isOpen; }
	void fill(ref char[] toFill)
	{
		try
		{
			toFill = file.rawRead(toFill);
			if (toFill.length == 0)
				file.detach();
		} 
		catch(Throwable t)
		{
			throw new Error(t.msg);
		}
	}

}

struct StringRange
{
	private	const(char)[] front;
	this(const(char)[] str)
	{
		this.front = str;
	}

nothrow:
	bool empty() { return front.length == 0; }
	void fill(ref char[] toFill)
	{
		size_t size = min(toFill.length, front.length);
		toFill[0 .. size] = front[0 .. size];
		toFill	= toFill[0 .. size];
		front = front[size .. $];
	}
}

@nogc nothrow:
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
	nextMember,
	itemDivider,
	error
}

//Unimplemented features:
//type1 name as type2 = type1(...)
//alias Type = type
//Ex: 
//string texture as HashID = "boat"
//alias Map = string[int[]] 
//Map m = Map( (1, 2, 3) : "hello" ) --Retarded example i know. 

struct SidalToken
{
	TokenTag tag;
	union
	{
		char[]	   value;
		double	   floating;
		ulong	   integer;
		size_t	   level;
	}
}
struct SidalRange
{
	enum terminator = '\0';
	RangeType type;
	//Workaround for union. 
	//union
	//{
	//	ByChunkRange chunk;
	//  StringRange  string;
	//}
	void[max(ByChunkRange.sizeof, StringRange.sizeof)] range_data;
	void chunk(ref ByChunkRange range) { *(cast(ByChunkRange*)range_data) = range; } 
	void string(ref StringRange range) { *(cast(StringRange*)range_data) = range; } 
	nothrow ByChunkRange* chunk()  { return cast(ByChunkRange*)range_data.ptr; }
	nothrow StringRange*  string() { return cast(StringRange*)range_data.ptr; }
	char[] buffer;
	char*  bptr;
	size_t length;

	size_t level, lines;
	SidalToken front;
	bool empty;

	this(ByChunkRange range, char[] buffer)
	{
		this.type   = RangeType.file;
		this.chunk  = range;
		this.buffer = buffer;
		this.length = 0;
		this.level = 0;
		this.empty = subEmpty();
		if(!empty)
		{
			nextBuffer();
			popFront();
		}
	}

	this(StringRange range, char[] buffer)
	{
		this.type	= RangeType.string;
		this.string = range;
		this.buffer = buffer;
		this.length = 0;
		this.level = 0;
		this.empty = subEmpty();
		if(!empty)
		{
			nextBuffer();
			popFront();
		}
	}

	bool subEmpty() 
	{
		if(length == 0)
		{
			final switch(type)
			{
				case RangeType.file:   return chunk.empty; break;
				case RangeType.string: return string.empty; break;
			}
		}
		return false;
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

	void nextBuffer()
	{
		char[] data	= buffer[0 .. $ - 1];
		final switch(type)
		{
			case RangeType.file:	chunk.fill(data);  break;
			case RangeType.string:	string.fill(data); break;
		}
		data.ptr[data.length] = '\0';
		bptr	= buffer.ptr;
		length = data.length;
	}	

	void moveBuffer(ref char* start)
	{
		size_t size = length - (start - buffer.ptr);
		import std.c.string;
		memmove(buffer.ptr, start, size);

		char[] data	= buffer[size .. $ - 1];
		final switch(type)
		{
			case RangeType.file:	chunk.fill(data);  break;
			case RangeType.string:	string.fill(data); break;
		}
		data.ptr[data.length] = '\0';
		start  = buffer.ptr;
		bptr   = &buffer.ptr[size];
		length = data.length + size;
	}


	void parseSuperValue()
	{
outer:	
		for(;;advance()) 
retry:
		switch(bfront)
		{
			case '\n': 
				lines++; 
				goto case;
			case ' ': case '\t': case '\r': break;
			case ',':
				front.tag = TokenTag.nextMember;
				front.level = level;
				advance();
				break outer;
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
				parseString(bptr);
				return;
			case '0': .. case '9':
			case '.': case '+': case '-':
				//We have a number :O cool. 
				//We inline it since the compiler does not want to
				//and it makes it faste gcc might do this but i cannot test :(
				//parseNumber(bptr);
				char* b = bptr;
				int sign = 1;
				for(;; advance()) 
					numberRetry:	
				switch(bfront)
				{
					default:
						goto numberSuccess;
					case '_': 
						break;
					case terminator:
						moveBuffer(b);
						if(bfront == terminator)
							goto numberSuccess;
						goto numberRetry;
					case '0': .. case '9':
						*bptr -= '0';
						break;
					case 'x': case 'X':
						//Numbers like: 1234xavier
						if(!(bptr - b == 1 && *b == cast(char)0))
							goto numberFail; //Since x is valid after a number? Sure why not. 

						//We have a hex number on the form 0xyyyyyyyyyyyyyyy
						advance();
						//We inline it for speed since the complier refuses to inline it.
						//parseHex(sign);

				hex:	for(;; advance()) 
				hexRetry:
						switch(bfront)
						{
							case '0': .. case '9':
								*bptr		-= '0';
								break;
							case 'a': .. case 'f':
								*bptr		-= cast(char)('a' + 10);
								break;
							case 'A': .. case 'F':
								*bptr		-= cast(char)('A' + 10);
								break;
							case terminator:
								moveBuffer(b);
								if(bfront == terminator)
									break hex;
								goto hexRetry;
							default: break hex;
						}

						uint value = 0;
						auto end    = bptr;
						switch(min(8, end - b)) 
						{
							case 8: value += end[-8] * 0x10000000; goto case;
							case 7: value += end[-7] * 0x1000000; goto case;
							case 6: value += end[-6] * 0x100000; goto case;
							case 5: value += end[-5] * 0x10000; goto case;
							case 4: value += end[-4] * 0x1000; goto case;
							case 3: value += end[-3] * 0x100; goto case;
							case 2: value += end[-2] * 0x10; goto case;
							case 1: value += end[-1];	break;
							default: break;
						}

						if(end - b > 8)
						{
							ulong lvalue = cast(ulong)value << 32;
							value		 = 0;
							end			-= 8;
							switch(end - b)  
							{
								case 8: value += end[-7] * 0x10000000; goto case;
								case 7: value += end[-6] * 0x1000000; goto case;
								case 6: value += end[-5] * 0x100000; goto case;
								case 5: value += end[-4] * 0x10000; goto case;
								case 4: value += end[-3] * 0x1000; goto case;
								case 3: value += end[-2] * 0x100; goto case;
								case 2: value += end[-1] * 0x10; goto case;
								case 1: value += end[0];	break;
								default: break;
							}
							lvalue |= value;
							front.tag	  = TokenTag.integer;
							front.integer = lvalue * sign; 
						}
						else 
						{	
							front.tag	  = TokenTag.integer;
							front.integer = value;
						}
						return;
					case '+':
						//Numbers like 10+14 don't work
						if(b !is bptr)
							goto numberFail;
						break;
					case '-': 
						//Numbers like 10-14 don't work
						if(b !is bptr)
							goto numberFail;
						sign = -1;
						break;
					case '.':
						//Number has a dot! That means they are floating!
						//We inline it since the function overhead is actually relevant.
						//parseFloat(sign, b); 
						double begin = void, end = void;
						uint value = 0;
						switch (bptr - b) 
						{ // handle up to 10 digits, 32-bit ints
							case 10:    value += bptr[-10] * 1000000000; goto case;
							case  9:    value += bptr[-9 ] * 100000000; goto case;
							case  8:    value += bptr[-8 ] * 10000000; goto case;	
							case  7:    value += bptr[-7 ] * 1000000; goto case;
							case  6:    value += bptr[-6 ] * 100000;	goto case;
							case  5:    value += bptr[-5 ] * 10000; goto case;
							case  4:    value += bptr[-4 ] * 1000; goto case;
							case  3:    value += bptr[-3 ] * 100; goto case;
							case  2:    value += bptr[-2 ] * 10;	goto case;
							case  1:    value += bptr[-1 ]; break;
							default: break;
						}
						begin = value;

						advance();
				float_:	for(b = bptr;; advance())
				floatNext:	
						switch(bfront)
						{
							case '0': .. case '9': *bptr -= '0'; break;
							case terminator:
								moveBuffer(b);
								if(bfront == terminator)
									break float_;
								goto floatNext;
							default: break float_;
						}

						value = 0;
						switch (bptr - b) 
						{ // handle up to 10 digits, 32-bit ints
							case 10:    value += bptr[-10] * 1000000000; goto case;
							case  9:    value += bptr[-9 ] * 100000000; goto case;
							case  8:    value += bptr[-8 ] * 10000000; goto case;	
							case  7:    value += bptr[-7 ] * 1000000; goto case;
							case  6:    value += bptr[-6 ] * 100000;	goto case;
							case  5:    value += bptr[-5 ] * 10000; goto case;
							case  4:    value += bptr[-4 ] * 1000; goto case;
							case  3:    value += bptr[-3 ] * 100; goto case;
							case  2:    value += bptr[-2 ] * 10;	goto case;
							case  1:    value += bptr[-1 ]; break;
							default: break;
						}
						__gshared static double[11] powE = [ 0.0, 1.0e-1, 1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5,
						1.0e-6, 1.0e-7, 1.0e-8, 1.0e-9, 1.0e-10];
						end = powE.ptr[bptr - b] * value;
						front.tag = TokenTag.floating;
						front.floating = (begin + end) * sign;
						return;
				}

			numberFail:
				makeError();
				return;

			numberSuccess:
				front.tag  = TokenTag.integer;
				uint value = 0;
				switch (bptr - b) 
				{ // handle up to 10 digits, 32-bit ints
					case 10:    value += bptr[-10] * 1000000000; goto case;
					case  9:    value += bptr[-9 ] * 100000000; goto case;
					case  8:    value += bptr[-8 ] * 10000000; goto case;	
					case  7:    value += bptr[-7 ] * 1000000; goto case;
					case  6:    value += bptr[-6 ] * 100000;	goto case;
					case  5:    value += bptr[-5 ] * 10000; goto case;
					case  4:    value += bptr[-4 ] * 1000; goto case;
					case  3:    value += bptr[-3 ] * 100; goto case;
					case  2:    value += bptr[-2 ] * 10;	goto case;
					case  1:    value += bptr[-1 ]; break;
					default: break;
				}
				if(bptr - b > 10)
				{	
					ulong lval = value;
					value = 0;
					switch (bptr - b) 
					{ // handle up to 10 digits, 32-bit ints
						case 10:    value += bptr[-10] * 1000000000; goto case;
						case  9:    value += bptr[-9 ] * 100000000; goto case;
						case  8:    value += bptr[-8 ] * 10000000; goto case;	
						case  7:    value += bptr[-7 ] * 1000000; goto case;
						case  6:    value += bptr[-6 ] * 100000; goto case;
						case  5:    value += bptr[-5 ] * 10000; goto case;
						case  4:    value += bptr[-4 ] * 1000; goto case;
						case  3:    value += bptr[-3 ] * 100; goto case;
						case  2:    value += bptr[-2 ] * 10; goto case;
						case  1:    value += bptr[-1 ]; break;
						default: assert(false, "Integer overflow!"); break;
					}
					lval |= cast(ulong)(value) << 32;
					front.integer = lval * sign;
				}
				else 
				{
					front.integer = value * sign;
				}

				return;
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '_': 
				//We parse an identifier name or type
				//parseType(bptr);
				char* b = bptr;
				size_t lbrackcount, rbrackcount;
				for(;;advance()) 
					typeRetry:			
				switch(bfront)
				{
					case terminator:
						moveBuffer(b);
						if(bfront == terminator)
							goto typeSuccess;
						else 
							goto typeRetry;
					default:  
						goto typeSuccess;
					case '\n': lines++; goto case;
					case ' ': case '\t': case '\r': 
						goto typeSuccess;
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
			typeFail:
				makeError();
				return;

			typeSuccess:
				if(lbrackcount != rbrackcount)
					goto typeFail;

				size_t size = bptr - b;
				lbrackcount = rbrackcount = 0;
				for(;; advance())
				{
				typeRetry2:
					switch(bfront)
					{
						case terminator:
							moveBuffer(b);
							if(bfront == terminator)
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
						case '\n': lines++; break;
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
				return;
			case terminator:
				nextBuffer();
				if(bfront == terminator)
				{
					this.empty = true;
					return;
				}
				goto retry;		
			default: assert(0);
		}
	}	

	void parseString(char* b)
	{
		advance();
outer:
		for(;; advance()) 
		{
retry:
			switch(bfront)
			{
				case '"': 
					front.tag   = TokenTag.string;
					front.value = b[0 .. bptr - b];
					advance();
					return;
				case terminator:
					moveBuffer(b);
					if(bfront == terminator)
						break outer;
					goto retry;
				default: break;
			}
		}

		makeError();
	}

	void parseHex(char* b, int sign)
	{
hex:	for(;; advance()) 
hexRetry:
		switch(bfront)
		{
			case '0': .. case '9':
				*bptr		-= '0';
				break;
			case 'a': .. case 'f':
				*bptr		-= cast(char)('a' + 10);
				break;
			case 'A': .. case 'F':
				*bptr		-= cast(char)('A' + 10);
				break;
			case terminator:
				moveBuffer(b);
				if(bfront == terminator)
					break hex;
				goto hexRetry;
			default: break hex;
		}

		uint value = 0;
		auto end    = bptr;
		switch(min(8, end - b)) //Think this is correct.  
		{
			case 8: value += end[-8] * 0x10000000; goto case;
			case 7: value += end[-7] * 0x1000000; goto case;
			case 6: value += end[-6] * 0x100000; goto case;
			case 5: value += end[-5] * 0x10000; goto case;
			case 4: value += end[-4] * 0x1000; goto case;
			case 3: value += end[-3] * 0x100; goto case;
			case 2: value += end[-2] * 0x10; goto case;
			case 1: value += end[-1];	break;
			default: break;
		}

		if(end - b > 8)
		{
			ulong lvalue = cast(ulong)value << 32;
			value		 = 0;
			end			-= 8;
			switch(end - b) //Think this is correct.  
			{
				case 8: value += end[-7] * 0x10000000; goto case;
				case 7: value += end[-6] * 0x1000000; goto case;
				case 6: value += end[-5] * 0x100000; goto case;
				case 5: value += end[-4] * 0x10000; goto case;
				case 4: value += end[-3] * 0x1000; goto case;
				case 3: value += end[-2] * 0x100; goto case;
				case 2: value += end[-1] * 0x10; goto case;
				case 1: value += end[0];	break;
				default: break;
			}
			lvalue |= value;
			front.tag	  = TokenTag.integer;
			front.integer = lvalue * sign; 
		}
		else 
		{	
			front.tag	  = TokenTag.integer;
			front.integer = value;
		}
	}

	void parseFloat(int sign, char* b)
	{
		double begin = void, end = void;

		uint value = 0;
		switch (bptr - b) 
		{ // handle up to 10 digits, 32-bit ints
			case 10:    value += bptr[-10] * 1000000000; goto case;
			case  9:    value += bptr[-9 ] * 100000000; goto case;
			case  8:    value += bptr[-8 ] * 10000000; goto case;	
			case  7:    value += bptr[-7 ] * 1000000; goto case;
			case  6:    value += bptr[-6 ] * 100000;	goto case;
			case  5:    value += bptr[-5 ] * 10000; goto case;
			case  4:    value += bptr[-4 ] * 1000; goto case;
			case  3:    value += bptr[-3 ] * 100; goto case;
			case  2:    value += bptr[-2 ] * 10;	goto case;
			case  1:    value += bptr[-1 ]; break;
			default: break;
		}
		begin = value;

		advance();
float_:	for(b = bptr;; advance())
floatNext:	
		switch(bfront)
		{
			case '0': .. case '9': *bptr -= '0'; break;
			case terminator:
				moveBuffer(b);
				if(bfront == terminator)
					break float_;
				goto floatNext;
			default: break float_;
		}

		value = 0;
		switch (bptr - b) 
		{ // handle up to 10 digits, 32-bit ints
			case 10:    value += bptr[-10] * 1000000000; goto case;
			case  9:    value += bptr[-9 ] * 100000000; goto case;
			case  8:    value += bptr[-8 ] * 10000000; goto case;	
			case  7:    value += bptr[-7 ] * 1000000; goto case;
			case  6:    value += bptr[-6 ] * 100000;	goto case;
			case  5:    value += bptr[-5 ] * 10000; goto case;
			case  4:    value += bptr[-4 ] * 1000; goto case;
			case  3:    value += bptr[-3 ] * 100; goto case;
			case  2:    value += bptr[-2 ] * 10;	goto case;
			case  1:    value += bptr[-1 ]; break;
			default: break;
		}

		end = value;
		switch(bptr - b)
		{
			case 10: end *= 10e-10; break;
			case 9:  end *= 10e-9;  break;
			case 8:  end *= 10e-8;   break;
			case 7:  end *= 10e-7;   break;
			case 6:  end *= 10e-6;   break;
			case 5:  end *= 10e-5;   break;
			case 4:  end *= 10e-4;   break;
			case 3:  end *= 10e-3;   break;
			case 2:  end *= 10e-2;   break;
			case 1:  end *= 10e-1;   break;
			default:
				end = 0; //We don't care about higher precision then 10e-10
				break;
		}

		front.tag = TokenTag.floating;
		front.floating = (begin + end) * sign;
	}	

	import std.c.stdio;
	void parseNumber(char* b)
	{
		int sign = 1;
		for(;; advance()) 
numberRetry:	
		switch(bfront)
		{
			default:
				goto numberSuccess;
			case '_': 
				break;
			case terminator:
				moveBuffer(b);
				if(bfront == terminator)
					goto numberSuccess;
				goto numberRetry;
			case '0': .. case '9':
				*bptr -= '0';
				break;
			case 'x': case 'X':
				//Numbers like: 1234xavier
				if(!(bptr - b == 1 && *b == cast(char)0))
					goto numberFail; //Since x is valid after a number? Sure why not. 

				//We have a hex number on the form 0xyyyyyyyyyyyyyyy
				advance();
				//We inline it for speed since the complier refuses to inline it.
				//parseHex(sign);

		hex:	for(;; advance()) 
		hexRetry:
				switch(bfront)
				{
					case '0': .. case '9':
						*bptr		-= '0';
						break;
					case 'a': .. case 'f':
						*bptr		-= cast(char)('a' + 10);
						break;
					case 'A': .. case 'F':
						*bptr		-= cast(char)('A' + 10);
						break;
					case terminator:
						moveBuffer(b);
						if(bfront == terminator)
							break hex;
						goto hexRetry;
					default: break hex;
				}

				uint value = 0;
				auto end    = bptr;
				switch(min(8, end - b)) //Think this is correct.  
				{
					case 8: value += end[-8] * 0x10000000; goto case;
					case 7: value += end[-7] * 0x1000000; goto case;
					case 6: value += end[-6] * 0x100000; goto case;
					case 5: value += end[-5] * 0x10000; goto case;
					case 4: value += end[-4] * 0x1000; goto case;
					case 3: value += end[-3] * 0x100; goto case;
					case 2: value += end[-2] * 0x10; goto case;
					case 1: value += end[-1];	break;
					default: break;
				}

				if(end - b > 8)
				{
					ulong lvalue = cast(ulong)value << 32;
					value		 = 0;
					end			-= 8;
					switch(end - b) //Think this is correct.  
					{
						case 8: value += end[-7] * 0x10000000; goto case;
						case 7: value += end[-6] * 0x1000000; goto case;
						case 6: value += end[-5] * 0x100000; goto case;
						case 5: value += end[-4] * 0x10000; goto case;
						case 4: value += end[-3] * 0x1000; goto case;
						case 3: value += end[-2] * 0x100; goto case;
						case 2: value += end[-1] * 0x10; goto case;
						case 1: value += end[0];	break;
						default: break;
					}
					lvalue |= value;
					front.tag	  = TokenTag.integer;
					front.integer = lvalue * sign; 
				}
				else 
				{	
					front.tag	  = TokenTag.integer;
					front.integer = value;
				}
				return;
			case '+':
				//Numbers like 10+14 don't work
				if(b !is bptr)
					goto numberFail;
				break;
			case '-': 
				//Numbers like 10-14 don't work
				if(b !is bptr)
					goto numberFail;
				sign = -1;
				break;
			case '.':
				//Number has a dot! That means they are floating!
				//We inline it since the function overhead is actually relevant.
				//parseFloat(sign, b); 
				double begin = void, end = void;
				uint value = 0;
				switch (bptr - b) 
				{ // handle up to 10 digits, 32-bit ints
					case 10:    value += bptr[-10] * 1000000000; goto case;
					case  9:    value += bptr[-9 ] * 100000000; goto case;
					case  8:    value += bptr[-8 ] * 10000000; goto case;	
					case  7:    value += bptr[-7 ] * 1000000; goto case;
					case  6:    value += bptr[-6 ] * 100000;	goto case;
					case  5:    value += bptr[-5 ] * 10000; goto case;
					case  4:    value += bptr[-4 ] * 1000; goto case;
					case  3:    value += bptr[-3 ] * 100; goto case;
					case  2:    value += bptr[-2 ] * 10;	goto case;
					case  1:    value += bptr[-1 ]; break;
					default: break;
				}
				begin = value;

				advance();
		float_:	for(b = bptr;; advance())
		floatNext:	
				switch(bfront)
				{
					case '0': .. case '9': *bptr -= '0'; break;
					case terminator:
						moveBuffer(b);
						if(bfront == terminator)
							break float_;
						goto floatNext;
					default: break float_;
				}

				value = 0;
				switch (bptr - b) 
				{ // handle up to 10 digits, 32-bit ints
					case 10:    value += bptr[-10] * 1000000000; goto case;
					case  9:    value += bptr[-9 ] * 100000000; goto case;
					case  8:    value += bptr[-8 ] * 10000000; goto case;	
					case  7:    value += bptr[-7 ] * 1000000; goto case;
					case  6:    value += bptr[-6 ] * 100000;	goto case;
					case  5:    value += bptr[-5 ] * 10000; goto case;
					case  4:    value += bptr[-4 ] * 1000; goto case;
					case  3:    value += bptr[-3 ] * 100; goto case;
					case  2:    value += bptr[-2 ] * 10;	goto case;
					case  1:    value += bptr[-1 ]; break;
					default: break;
				}
				__gshared static double[11] powE = [ 0.0, 1.0e-1, 1.0e-2, 1.0e-3, 1.0e-4, 1.0e-5,
														  1.0e-6, 1.0e-7, 1.0e-8, 1.0e-9, 1.0e-10];
				end = powE.ptr[bptr - b] * value;
				front.tag = TokenTag.floating;
				front.floating = (begin + end) * sign;
				return;
		}

numberFail:
		makeError();
		return;

numberSuccess:
		front.tag  = TokenTag.integer;
		uint value = 0;
		switch (bptr - b) 
		{ // handle up to 10 digits, 32-bit ints
			case 10:    value += bptr[-10] * 1000000000; goto case;
			case  9:    value += bptr[-9 ] * 100000000; goto case;
			case  8:    value += bptr[-8 ] * 10000000; goto case;	
			case  7:    value += bptr[-7 ] * 1000000; goto case;
			case  6:    value += bptr[-6 ] * 100000;	goto case;
			case  5:    value += bptr[-5 ] * 10000; goto case;
			case  4:    value += bptr[-4 ] * 1000; goto case;
			case  3:    value += bptr[-3 ] * 100; goto case;
			case  2:    value += bptr[-2 ] * 10;	goto case;
			case  1:    value += bptr[-1 ]; break;
			default: break;
		}
		if(bptr - b > 10)
		{	
			ulong lval = value;
			value = 0;
			switch (bptr - b) 
			{ // handle up to 10 digits, 32-bit ints
				case 10:    value += bptr[-10] * 1000000000; goto case;
				case  9:    value += bptr[-9 ] * 100000000; goto case;
				case  8:    value += bptr[-8 ] * 10000000; goto case;	
				case  7:    value += bptr[-7 ] * 1000000; goto case;
				case  6:    value += bptr[-6 ] * 100000; goto case;
				case  5:    value += bptr[-5 ] * 10000; goto case;
				case  4:    value += bptr[-4 ] * 1000; goto case;
				case  3:    value += bptr[-3 ] * 100; goto case;
				case  2:    value += bptr[-2 ] * 10; goto case;
				case  1:    value += bptr[-1 ]; break;
				default: assert(false, "Integer overflow!"); break;
			}
			lval |= cast(ulong)(value) << 32;
			front.integer = lval * sign;
		}
		else 
		{
			front.integer = value * sign;
		}

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
		for(;;advance()) 
typeRetry:			
		switch(bfront)
		{
			case terminator:
				moveBuffer(b);
				if(bfront == terminator)
					goto typeSuccess;
				else 
					goto typeRetry;
			default:  
				goto typeSuccess;
			case '\n': lines++; goto case;
			case ' ': case '\t': case '\r': 
				goto typeSuccess;
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
typeFail:
	makeError();
	return;

typeSuccess:
		if(lbrackcount != rbrackcount)
			goto typeFail;

		size_t size = bptr - b;
		lbrackcount = rbrackcount = 0;
		for(;; advance())
		{
typeRetry2:
			switch(bfront)
			{
				case terminator:
					moveBuffer(b);
					if(bfront == terminator)
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
				case '\n': lines++; break;
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
	}

	void makeError()
	{
		assert(false);
		//front = sidalToken(TokenTag.error, 0);
		front.tag = TokenTag.error;
	}
}


ulong stringToLong(char* p, size_t s)
{
	ulong value_ = 0;
	auto end	 = p + s;
	switch (s) 
	{ // handle up to 20 digits, 64-bit ints
		case 19:    value_ += end[-19] * 1000000000000000000; goto case;
		case 18:    value_ += end[-18] * 100000000000000000; goto case;
		case 17:    value_ += end[-17] * 10000000000000000; goto case;
		case 16:    value_ += end[-16] * 1000000000000000; goto case;
		case 15:    value_ += end[-15] * 100000000000000; goto case;
		case 14:    value_ += end[-14] * 10000000000000; goto case;
		case 13:    value_ += end[-13] * 1000000000000; goto case;
		case 12:    value_ += end[-12] * 100000000000; goto case;
		case 11:    value_ += end[-11] * 10000000000; goto case;
		case 10:    value_ += end[-10] * 1000000000; goto case;
		case  9:    value_ += end[-9 ] * 100000000; goto case;
		case  8:    value_ += end[-8 ] * 10000000;	goto case;	
		case  7:    value_ += end[-7 ] * 1000000; goto case;
		case  6:    value_ += end[-6 ] * 100000; goto case;
		case  5:    value_ += end[-5 ] * 10000; goto case;
		case  4:    value_ += end[-4 ] * 1000; goto case;
		case  3:    value_ += end[-3 ] * 100; goto case;
		case  2:    value_ += end[-2 ] * 10; goto case;
		case  1:    value_ += end[-1 ];
			return value_;
		default:
			assert(false, "Integer overflow!");
	}
}

uint stringToInt(char* p, size_t s)
{
	uint value = 0;
	auto end	= p + s;
	switch (s) 
	{ // handle up to 10 digits, 32-bit ints
		case 10:    value += end[-10] * 1000000000; goto case;
		case  9:    value += end[-9 ] * 100000000; goto case;
		case  8:    value += end[-8 ] * 10000000; goto case;	
		case  7:    value += end[-7 ] * 1000000; goto case;
		case  6:    value += end[-6 ] * 100000;	goto case;
		case  5:    value += end[-5 ] * 10000; goto case;
		case  4:    value += end[-4 ] * 1000; goto case;
		case  3:    value += end[-3 ] * 100; goto case;
		case  2:    value += end[-2 ] * 10;	goto case;
		case  1:    value += end[-1 ]; break;
		default: break;
	}

	return value;
}