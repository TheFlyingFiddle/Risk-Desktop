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
		alias FullyUnqual = FullyUnqual!(U)[];
	else
		alias FullyUnqual = Unqual!T;
}

template GetCtType(alias aggrigate, string symbol)
{
	//Might be generated typeinfo which is not very interesting
	static if(!__traits(compiles, Alias!(__traits(getMember, aggrigate, symbol))))
	{
		enum GetCtType = CtType.noType;
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
				static if(is(aggrigate))
				{
					enum cantakeaddr = __traits(compiles, mixin("&aggrigate.init." ~ symbol));
					static if(cantakeaddr)
						enum isInstanceField = true;
					else 
						enum isInstanceField = false;
				}
				else 
					enum isInstanceField = false;
			}

			template isEnumConstant()
			{
				static if(__traits(compiles, typeof(mem)))
				{
					static if(!__traits(compiles, () => &mem))
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
					enum GetCtType = CtType.class_;
				}
				else static if(is(mem == struct))
				{
					enum GetCtType = CtType.struct_;
				}
				else static if(is(mem == interface))
				{
					enum GetCtType = CtType.interface_;
				}
				else static if(is(mem == enum))
				{
					enum GetCtType = CtType.enum_;
				}
				else static if(isModule!())
				{
					enum GetCtType = CtType.module_;
				}
				else static if(is(typeof(mem) == function))
				{
					enum GetCtType = CtType.function_;
				}
				else static if(isTemplate!())
				{
					enum GetCtType = CtType.template_;
				}
				else static if(isStaticField!())
				{
					enum GetCtType = CtType.staticField_;
				}
				else static if(isInstanceField!())
				{
					enum GetCtType = CtType.instanceField_;
				}
				else static if(isEnumConstant!())
				{
					enum GetCtType = CtType.enumConstant_ ;
				}
				else 
				{
					static assert(0, "Uknown compile time symbol type! " ~ mem.stringof);
				}
			} 
			else 
			{
				enum GetCtType = CtType.alias_;
			}
		}
		else 
		{
			static if(__traits(isStaticFunction, mem))
			{
				enum GetCtType = CtType.function_;
			}
			else static if(isSomeFunction!mem) 
			{
				enum GetCtType = CtType.method_;
			}
			else 
				enum GetCtType = CtType.primitive_;
		}
	}
}

template AllMembers(T...) if(T.length == 1) 
{	
	template commonFilter(string sym)
	{
		enum type = MemberType!(T[0], sym);
		enum commonFilter = type != CtType.noType;
	}
	alias Filter!(commonFilter, __traits(allMembers, T[0])) AllMembers;
}

template Members(CtType type, alias aggregate)
{
	alias staticMap!(GetMember!(aggregate), MemberSymbols!(type, aggregate)) Members;
}

template MemberSymbols(CtType type, alias aggregate)
{
	template filt(string sym)
	{
		enum reflType = GetCtType!(aggregate, sym);
		enum filt = (reflType & type) == reflType && reflType != CtType.noType;
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

enum CtType
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

template Aliases(alias T)
{
	template helper(string symbol)
	{
		alias mem = Alias!(__traits(getMember, T, symbol));
		alias helper = AliasInfo!(symbol, mem);
	}

	alias Aliases = staticMap!(helper, MemberSymbols!(CtType.alias_, T));
}

template AliasInfo(string id, T...)
{
	alias value = T;
	enum ident = id;
}

template HasAttribute(T)
{
	enum test(alias symbol) = exists!(T, symbol.attribs);
	alias HasAttribute = test;
}

template CtTypes(alias T, CtType type, alias Construct)
{
	alias helper(string symbol) = Construct!(T, symbol);
	alias all					= staticMap!(helper, MemberSymbols!(type, T));
	alias That(alias pred)		= Filter!(pred, all);
}

alias Fields(alias T) = CtTypes!(T, CtType.instanceField_, Field);
template Field(alias parent, string symbol)
{
	enum id        = symbol;
	alias mem      = AliasSeq!(__traits(getMember, parent, symbol))[0];
	alias type     = typeof(mem);
	enum offset    = mem.offsetof;
	alias attribs  = AliasSeq!(__traits(getAttributes, mem));

	alias parentType = parent;
	void set(T)(ref parentType p, auto ref T t) if(is(T == type))
	{
		mixin("p." ~ symbol ~ " = " ~ t ~ ";");
	}
}

alias SFields(alias T) = CtTypes!(T, CtType.staticField_, SField);
template SField(alias parent, string symbol)
{
	enum id		   = symbol;
	alias mem	   = AliasSeq!(__traits(getMember, parent, symbol))[0];
	enum addr	   = &mem;

	alias type     = typeof(mem);
	alias attribs  = AliasSeq!(__traits(getAttributes, mem));
}

alias Structs(alias T) = CtTypes!(T, CtType.struct_, Struct);
template Struct(alias parent, string symbol)
{
	enum  id		 = symbol;
	alias type       = AliasSeq!(__traits(getMember, parent, symbol));
	alias fields     = Fields!(type);
	alias functions  = Functions!(type);
	alias methods    = Methods!(type);
	alias sfields	 = SFields!(type);
	alias enums		 = Enums!(type);
	alias structs    = Structs!(type);
	alias classes    = Classes!(type);
	alias interfaces = Interfaces!(type);
	alias constants  = Constants!(type);
	alias aliases	 = Aliases!(type);
	alias attribs    = AliasSeq!(__traits(getAttributes, mixin("parent." ~ symbol)));
}


alias Classes(alias T)   = CtTypes!(T, CtType.class_, Class);
template Class(alias parent, string symbol)
{
	enum id          = symbol;
	alias type       = AliasSeq!(__traits(getMember, parent, symbol));
	alias fields     = Fields!(type);
	alias functions  = SFields!(type);
	alias methods    = Methods!(type);
	alias sfields    = SFields!(type);
	alias enums		 = Enums!(type);
	alias structs    = Structs!(type);
	alias classes    = Classes!(type);
	alias interfaces = Interfaces!(type);
	alias constants  = Constants!(type);
	alias aliases    = Aliases!(type);
	alias attribs	 = AliasSeq!(__traits(getAttributes, mixin("parent." ~ symbol)));
}

alias Interfaces(alias T) = CtTypes!(T, CtType.interface_, Interface);
template Interface(alias parent, string symbol)
{
	enum id			 = symbol;
	alias type		 = AliasSeq!(__traits(getMember, parent, symbol));
	alias methods	 = Methods!(type);
}

alias Enums(alias T) = CtTypes!(T, CtType.enum_, Enum);
template Enum(alias parent, string symbol)
{
	alias id		= symbol;
	alias type      = AliasSeq!(__traits(getMember, parent, symbol));
	alias members   = EnumMembers!(type);
}

alias Constants(alias T) = CtTypes!(T, CtType.enumConstant_, Constant);
template Constant(alias parent, string symbol)
{
	enum id			= symbol;
	enum value		= __traits(getMember, parent, symbol);
	alias type      = typeof(value);
}

alias Functions(alias T) = CtTypes!(T, CtType.function_, Function);
template Function(alias parent, string symbol)
{
	enum id = symbol;
}

alias Methods(alias T)   = CtTypes!(T, CtType.method_, Method);
template Method(alias parent, string symbol)
{
	enum id = symbol;
}

alias Imports(alias T)  = CtTypes!(T, CtType.module_, Import);
template Import(alias parent, string symbol)
{
	enum id = symbol;
}

template Module(alias symbol)
{
	enum id = __traits(identifier, symbol);
	alias fields     = SFields!(symbol);
	alias structs    = Structs!(symbol);
	alias classes    = Classes!(symbol);
	alias interfaces = Interfaces!(symbol);
	alias enums		 = Enums!(symbol);
	alias constants	 = EnumConstants!(symbol);
	alias aliases	 = Aliases!(symbol);
	alias functions  = Function!(symbol);
	alias imports	 = Imports!(symbol); //Does not go through them. 
	
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