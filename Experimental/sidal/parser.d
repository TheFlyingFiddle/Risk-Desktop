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
	void fill(ref char[] toFill)
	{
		if(inplace) 
		{	
			toFill = cast(char[])front;
			auto p = &front.ptr[front.length - 1];
			if(*p == '\0' || *(++p) == '\0')
				front = p[0 .. 0];
			return;
		}
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
	bool inplace;

	size_t level, lines, column;
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
		bptr	= data.ptr;
		length  = data.length;
		column += length;
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
		bptr   = data.ptr;
		length = data.length + size;		
		column += length;
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
				//return parseNumber(sign);
				//Inlining it for profit.
				ulong value = 0;
				for(;;advance())
				{
					if(bfront >= '0' && bfront <= '9')
						value = value * 10 + bfront - '0';
					else if(bfront == terminator)
					{
						nextBuffer();
						if(bfront == terminator)
							break;
					}
					else
						break;
				}

				switch(bfront)
				{
					default: break;
					case 'x' :  case 'X':
						advance();
						//parseHex(sign);
						value = 0;
						for(;; advance()) 
						{
							if(bfront >= '0' && bfront <= '9')
								value *= 0x10 + bfront - '0';
							else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
								value *= 0x10 + (bfront | 0x20) - 'a';
							else if(bfront == terminator)
							{
								nextBuffer();
								if(bfront == terminator)
									break;
							}	
							else 
								break;
						}

						front.tag	  = TokenTag.integer;
						front.integer = value;
						return;
					case '.':
						advance();
						//parseFloat(sign, value);
						double begin = value, end = void;
						auto start   = bptr;
						for(;;advance())
						{
							if(bfront >= '0' && bfront <= '9')
								value = value * 10 + bfront - '0';
							else if(bfront == terminator)
							{
								nextBuffer();
								if(bfront == terminator)
									break;
							}
							else
								break;
						}
						end  = value;
						end *= powE[bptr - start];
						front.tag = TokenTag.floating;
						front.floating = (begin + end) * sign;
						return;
				}

				front.tag     = TokenTag.integer;
				front.integer = value * sign;
				return;
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '_': 
				//We parse an identifier name or type
				//return parseType(bptr);
				//Inlining it for profit.
				char* b = bptr;
				size_t lbrackcount, rbrackcount;
			typeOuter:
				for(;;advance()) 
					typeRetry:			
				switch(bfront)
				{
					case terminator:
						moveBuffer(b);
						if(bfront == terminator)
							break typeOuter;
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
				nextBuffer();
				if(bfront == terminator)
					break;
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
		for(;;advance())
		{
			if(bfront >= '0' && bfront <= '9')
				value = value * 10 + bfront - '0';
			else if(bfront == terminator)
			{
				nextBuffer();
				if(bfront == terminator)
					break;
			}
			else
				break;
		}
		end  = value;
		end *= powE[bptr - start];
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
				nextBuffer();
				if(bfront == terminator)
					break;
			}
			else
				break;
		}

		switch(bfront)
		{
			default: break;
			case 'x' :  case 'X':
				advance();
				//parseHex(sign);
				value = 0;
				for(;; advance()) 
				{
					if(bfront >= '0' && bfront <= '9')
						value *= 0x10 + bfront - '0';
					else if((bfront | 0x20)  >= 'a' && (bfront | 0x20) <= 'f')
						value *= 0x10 + (bfront | 0x20) - 'a';
					else if(bfront == terminator)
					{
						nextBuffer();
						if(bfront == terminator)
							break;
					}	
					else 
						break;
				}

				front.tag	  = TokenTag.integer;
				front.integer = value;
				return;
			case '.':
				advance();
				//parseFloat(sign, value);
				double begin = value, end = void;
				auto start   = bptr;
				for(;;advance())
				{
					if(bfront >= '0' && bfront <= '9')
						value = value * 10 + bfront - '0';
					else if(bfront == terminator)
					{
						nextBuffer();
						if(bfront == terminator)
							break;
					}
					else
						break;
				}
				end  = value;
				end *= powE[bptr - start];
				front.tag = TokenTag.floating;
				front.floating = (begin + end) * sign;
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
				moveBuffer(b);
				if(bfront == terminator)
					break typeOuter;
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
}