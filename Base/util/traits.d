module util.traits;

public import std.traits;
public import std.typetuple;
import std.exception;
import std.algorithm;
import std.conv;
import std.string;

template retro(T...) {
	import std.typetuple;
	static if(T.length)
		alias retro = TypeTuple!(retro!(T[1 .. $]), T[0]);
	else 
		alias retro = TypeTuple!();
}

//std.range has ElementType!string == dchar 
//this is worthless for my purposes. 
template ElementType(T) 
{
	static if(is(T E : E[]))
		alias ElementType = E; 
	else static if(is(typeof(T.init.front.init) E))
		alias ElementType = E;
	else 
		alias ElementType = void;
}

template exists(alias item, T...)
{
	enum exists = staticIndexOf!(item, T) != -1;
}

template exists(T, U...)
{
	enum exists = staticIndexOf!(T, U) != -1;
}

template staticIota(size_t s, size_t e, size_t step = 1)
{
	import std.typetuple : TypeTuple;
	static if(s < e)
		alias staticIota = TypeTuple!(s, staticIota!(s + step, e, step));
	else 
		alias staticIota = TypeTuple!();
}

template GetMember(alias T)
{
	template GetMember(string sym)
	{
		static if(__traits(compiles, __traits(getMember, T, sym)))
		{
			alias mem = TypeTuple!(__traits(getMember, T, sym));
			static if(isSomeFunction!(mem[0]))
			{
				alias GetMember = TypeTuple!(__traits(getOverloads, T, sym));
			}
			else 
				alias GetMember = mem;
		}
		else 
		{
			alias TypeTuple!() GetMember;
		}
	}
}

template FullyUnqual(T) //Remove all typequalifiers!

{
	static if(is(T t == U[], U))
	{
		alias FullyUnqual = FullyUnqual!(U)[];
	}
	else
	{
		alias FullyUnqual = Unqual!T;
	}
}

template GetReflectionType(alias aggrigate, string symbol)
{
	//Might be generated typeinfo which is not very interesting
	static if(!__traits(compiles, Alias!(__traits(getMember, aggrigate, symbol))))
	{
		enum GetReflectionType = ReflectionType.noType;
	}
	else 
	{
		alias mem = Alias!(__traits(getMember, aggrigate, symbol));
		static if(__traits(compiles, mem.stringof))
		{
			enum str = mem.stringof;

			static if(__traits(compiles, __traits(identifier, mem)))
				enum id = __traits(identifier, mem);
			else 
			{
				enum id = "NO IDENTIFIER";
			}

			template isModule()
			{
				enum isModule = str.startsWith("module") || str.startsWith("package");
			}

			template isStaticField()
			{
				static if(__traits(compiles, typeof(mem)))
				{
					static if(__traits(compiles, () => &mem))
						enum isStaticField = true;
					else 
						enum isStaticField = false;
				}
				else 
					enum isStaticField = false;
			}
			
			template isInstanceField()
			{
				//Need to fix this 
				static if(__traits(compiles, typeof(mem)))
				{
					static if(!__traits(compiles, () => mem))
						enum isInstanceField = true;
					else 
						enum isInstanceField = false;
				}
				else 
					enum isInstanceField = false;
			}

			template isEnumConstant()
			{
				//Need to fix this 
				static if(__traits(compiles, typeof(mem)))
				{
					static if(__traits(compiles, () => mem))
						enum isEnumConstant = true;
					else 
						enum isEnumConstant = false;
				}
				else 
					enum isEnumConstant = false;
			}



			template isTemplate()
			{
				enum isTemplate = symbol.length < str.length && str[symbol.length] == '(';
			}

			static if(symbol == id)
			{		
				static if(is(mem == class))
				{
					enum GetReflectionType = ReflectionType.class_;
				}
				else static if(is(mem == struct))
				{
					enum GetReflectionType = ReflectionType.struct_;
				}
				else static if(is(mem == interface))
				{
					enum GetReflectionType = ReflectionType.interface_;
				}
				else static if(is(mem == enum))
				{
					enum GetReflectionType = ReflectionType.enum_;
				}
				else static if(isModule!())
				{
					enum GetReflectionType = ReflectionType.module_;
				}
				else static if(is(typeof(mem) == function))
				{
					enum GetReflectionType = ReflectionType.function_;
				}
				else static if(isTemplate!())
				{
					enum GetReflectionType = ReflectionType.template_;
				}
				else static if(isStaticField!())
				{
					enum GetReflectionType = ReflectionType.staticField_;
				}
				else static if(isInstanceField!())
				{
					enum GetReflectionType = ReflectionType.instanceField_;
				}
				else static if(isEnumConstant!())
				{
					enum GetReflectionType = ReflectionType.enumConstant_ ;
				}
				else 
				{
					static assert(0, "Uknown compile time symbol type! " ~ mem.stringof);
				}
			} 
			else 
			{
				enum GetReflectionType = ReflectionType.alias_;
			}
		}
		else 
		{
			static if(__traits(isStaticFunction, mem))
			{
				enum GetReflectionType = ReflectionType.function_;
			}
			else static if(isSomeFunction!mem) 
			{
				enum GetReflectionType = ReflectionType.method_;
			}
			else 
				enum GetReflectionType = ReflectionType.primitive_;
		}
	}
}

template AllMembers(T...) if(T.length == 1) 
{	
	template commonFilter(string sym)
	{
		enum type = MemberType!(T[0], sym);
		enum commonFilter = type != ReflectionType.noType;
	}
	alias Filter!(commonFilter, __traits(allMembers, T[0])) AllMembers;
}

template Members(ReflectionType type, alias aggregate)
{
	alias staticMap!(GetMember!(aggregate), MemberSymbols!(type, aggregate)) Members;
}

template MemberSymbols(ReflectionType type, alias aggregate)
{
	template filt(string sym)
	{
		enum reflType = GetReflectionType!(aggregate, sym);
		enum filt = (reflType & type) == reflType && reflType != ReflectionType.noType;
	}

	alias Filter!(filt, __traits(allMembers, aggregate)) MemberSymbols;
}

template Identifier(T...) if(T.length == 1)
{
	enum Identifier = __traits(identifier, T);
}

template isFunctionType(T)
{
	template isFunctionType(U...) if(U.length == 1)
	{
		enum isFunctionType = is(T == typeof(&U[0]));
	}
}

template isDelegateType(T) if(isDelegate!T)
{
	template isDelegateType(U...) if(U.length == 1)
	{
		enum isDelegateType = is(typeof(T.funcptr) == typeof(&U[0]));
	}
}

enum ReflectionType
{
	noType			= 0x0000,
	class_			= 0x0001,
	struct_			= 0x0002,
	interface_		= 0x0004,
	alias_			= 0x0008,
	enum_			= 0x0010,
	module_			= 0x0020,
	function_		= 0x0040,
	method_			= 0x0080,
	staticField_	= 0x0100,
	instanceField_	= 0x0200,
	template_		= 0x0400,
	primitive_		= 0x0800,
	enumConstant_   = 0x1000,
}


alias Classes		    (alias T) = Members!(ReflectionType.class_				, T);
alias Structs		    (alias T) = Members!(ReflectionType.struct_				, T);
alias Interfaces	    (alias T) = Members!(ReflectionType.interface_			, T);
alias Enums			    (alias T) = Members!(ReflectionType.enum_				, T);
alias Imports		    (alias T) = Members!(ReflectionType.module_				, T);
alias Functions		    (alias T) = Members!(ReflectionType.function_			, T);
alias Methods		    (alias T) = Members!(ReflectionType.method_				, T);
alias StaticFields	    (alias T) = Members!(ReflectionType.staticField_		, T);
alias InstanceFields	(alias T) = Members!(ReflectionType.instanceField_		, T);
alias EnumConstants	    (alias T) = Members!(ReflectionType.enumConstant_		, T);
alias Templates	    	(alias T) = Members!(ReflectionType.template_			, T);
alias Types		    	(alias T) = Members!(ReflectionType.class_		| 
									 ReflectionType.struct_		|
									 ReflectionType.interface_, T);
alias Callables (alias T) = Members!(ReflectionType.function_ | ReflectionType.method_, T);


template Aliases(alias T)
{
	template helper(string symbol)
	{
		alias mem = Alias!(__traits(getMember, T, symbol));
		alias helper = AliasInfo!(symbol, mem);
	}

	alias Aliases = staticMap!(helper, MemberSymbols!(ReflectionType.alias_, T));
}

struct AliasInfo(string id, T...)
{
	alias value = T;
	enum ident = id;
}

//Attributes below.
template hasAttribute(alias symbol, Attrib)
{
	template isAttributeT(U...) {
		enum isAttributeT = is(U[0] == Attrib);
	}

	alias hasAttribute = anySatisfy!(isAttributeT, __traits(getAttributes, symbol));
}


version(unittest) 
{
	struct Tag { @disable this(); }

	@Tag int tagged;
	int untagged;
}

unittest
{
	static assert(hasAttribute!(tagged, Tag));
	static assert(!hasAttribute!(untagged, Tag));
}

template hasValueAttribute(alias symbol, T)
{
	template isValueAttribute(U...) {
		enum isValueAttribute = is(typeof(U[0]) == T);
	}

	alias hasValueAttribute = anySatisfy!(isValueAttribute, __traits(getAttributes, symbol));
}

unittest
{
	struct Log { string s; }

	@Log("hello") int helloLog;
	@Log int tagLog;


	static assert(hasValueAttribute!(helloLog, Log));
	static assert(!hasValueAttribute!(tagLog, Log));
}

template getAttribute(alias symbol, T) if(hasValueAttribute!(symbol, T)) {

	template helper(U...)  {
		static if(is(typeof(U[0]) == T))
			enum helper = U[0];
		else 
			enum helper = helper!(U[1 .. $]);
	}

	enum getAttribute = 	helper!(__traits(getAttributes, symbol));
}

unittest
{

	struct Foo { string bar; }

	@Foo("Hello") int helloFoo;
	@Foo("Goodbye") int goodbyeFoo;

	static assert(getAttribute!(helloFoo, Foo) == Foo("Hello"));
	static assert(getAttribute!(goodbyeFoo, Foo) == Foo("Goodbye"));
}