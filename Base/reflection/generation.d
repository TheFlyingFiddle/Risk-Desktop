module reflection.generation;

import reflection.data;
import std.typetuple;
import std.traits;

import util.variant;
import util.hash;
import util.traits;

private __gshared static this()
{
	alias primitives = TypeTuple!(ubyte,  byte,
								  ushort, short,
								  uint,   int,
								  ulong,  long,
								  float,  double,
								  real,   bool,
								  void);	
	foreach(p; primitives)
	{
		MetaTypeData!(isTrue, p).pass0();
	}
}

mixin template GenerateMetaData(alias typeFilter, modules...)
{
	private __gshared static this()
	{
		try
		{
			foreach(mod; modules)
				ModuleMetaData!(typeFilter, mod).pass0();
		}
		catch(Throwable t)
		{
			import log;
			logInfo(t);
		}
	}
}

void addRTTI(T)(ref RTTI rtti)
{
	static if(__traits(compiles, T.init))
	{
		__gshared static defaultValue = T.init;
		rtti.defaultValue		= &defaultValue;
	}

	assembly.nameIndex[HashID(rtti.name)]				  = cast(ushort)assembly.rttis.length;
	assembly.qualifiedNameIndex[HashID(rtti.fullyQualifiedName)] = cast(ushort)assembly.rttis.length;
	assembly.rttis ~= rtti;
}

ushort rttiOffset(U)()
{
	import std.range;
	static if(isArray!U)
	{
		alias T = Unqual!(typeof(U.init[0]))[];
	}
	else 
		alias T = Unqual!U;


	enum hash = typeHash!T;
	auto p = HashID(hash.value) in assembly.qualifiedNameIndex;
	if(p)
		return *p;

	return ushort.max;
}

template ModuleMetaData(alias typeFilter, alias module_name)
{
	alias filteredFunctions   = Filter!(not!(isStaticCtor), Functions!(module_name));
	alias filteredClasses     = Classes!(module_name);
	alias filteredStructs     = Structs!(module_name);
	alias filteredFields      = StaticFields!(module_name);
	alias enums				  = Enums!(module_name);

	void pass0()
	{
		foreach(i, m;  filteredFunctions)
		{
			MetaTypeData!(typeFilter, ReturnType!m).pass0();
			foreach(p; ParameterTypeTuple!(m))
			{
				MetaTypeData!(typeFilter, p).pass0();
			}

			assembly.functions ~= makeFunction!(m);
		}

		foreach(enum_; enums)
		{
			MetaTypeData!(typeFilter, enum_).pass0();
		}

		auto start = assembly.types.length;
		foreach(i, type; filteredClasses) 
			MetaTypeData!(typeFilter, type).pass0();

		foreach(i, type; filteredStructs)
			MetaTypeData!(typeFilter, type).pass0();

		foreach(i, dummy; filteredFields)
		{
			assembly.staticFields ~= makeField!(Identifier!(filteredFields[i]));
		}

	}

	auto makeField(string s)()
	{
		alias field = TypeTuple!(__traits(getMember, module_name, s));

		StaticMetaField f;
		f.name					 = s;
		f.fullyQualifiedName     = fullyQualifiedName!field;
		f.assembly				 = &assembly;
		f.field					 = cast(void*)&field[0];
		f.fieldInfoOffset		 = rttiOffset!(typeof(field[0]));
		f.attributesInterval	 = makeAttributes!(__traits(getAttributes, field[0]));
		f.modifier				 = GetModifier!(typeof(field[0]));
		return f;
	}
}

void genFunction(alias func)()
{
	auto fun = makeFunction!(func);
	assembly.functions ~= fun;
}


MetaFunction makeFunction(alias func)()
{
	import dll.error;

	MetaFunction f;
	f.assembly		     = &assembly;
	f.name			     = fullyQualifiedName!func;

	alias d = ReturnType!func function(ParameterTypeTuple!func);
	f.hash			     = typeHash!(d); 

	f.funcptr		     = wrap!(func)();
	f.attributesInterval = makeAttributes!(__traits(getAttributes, func));
	f.parametersInterval = makeParameters!(func);
	f.returnOffset	     = rttiOffset!(ReturnType!func);
	return f;
}

template MetaTypeData(alias typeFilter, U : U*)
{
	alias T = FullyUnqual!U;
	static void pass0()
	{
		if(assembly.findInfo!(T*)) return;

		MetaTypeData!(typeFilter, T).pass0();

		RTTI rtti;
		rtti.name				= (T*).stringof;
		rtti.fullyQualifiedName = fullyQualifiedName!(T*);
		rtti.assembly			= &assembly;
		rtti.offset				= cast(ushort)assembly.rttis.length;
		rtti.innerOffset		= rttiOffset!(T);
		rtti.size				= size_t.sizeof;
		rtti.type				= RTTI.Type.pointer;
		rtti.hash				= typeHash!(T*);		
		addRTTI!T(rtti);
	}

	static void pass1()
	{
		//Do nothing in particular!
	}
}

template MetaTypeData(alias typeFilter, U : U[])
{
	alias T = FullyUnqual!(U);
	static void pass0()
	{
		if(assembly.findInfo!(T[])) return;

		MetaTypeData!(typeFilter, T).pass0();

		RTTI rtti;
		rtti.name	     = (T[]).stringof;
		rtti.fullyQualifiedName = fullyQualifiedName!(T[]);
		rtti.assembly    = &assembly;
		rtti.offset      = rttiOffset!(T);
		rtti.size		 = size_t.sizeof;
		rtti.type        = RTTI.Type.array;
		rtti.hash		 = typeHash!(T[]);		
		rtti.innerOffset = rttiOffset!(T);
		addRTTI!T(rtti);
	}

	static void pass1()
	{
		//Do nothing in particular!
	}
}

template MetaTypeData(alias typeFilter, U) if(is(U == enum))
{
	alias T = FullyUnqual!U;
	static void pass0() 
	{
		if(assembly.findInfo!T) return;

		RTTI rtti;
		rtti.name			    = T.stringof;
		rtti.fullyQualifiedName = fullyQualifiedName!(T);
		rtti.type				= RTTI.Type.enum_;
		rtti.size				= T.sizeof;
		rtti.assembly			= &assembly;
		rtti.offset				= cast(ushort)assembly.enums.length;
		rtti.hash				= typeHash!T;		
		
		addRTTI!T(rtti);

		MetaEnum enum_;
		enum_.rttiOffset = cast(ushort)(assembly.rttis.length - 1);
		enum_.assembly   = &assembly;

		auto interval = TinyInterval(assembly.constants.length, 
									 (EnumMembers!T).length);
		enum_.constantsInterval = interval;

		foreach(member; __traits(allMembers, T))
		{
			MetaConstant value;
			value.name  = member;
			mixin("value.value = T." ~ member ~";");
			assembly.constants ~= value;
		}

		assembly.enums ~= enum_;

	}
}

template MetaTypeData(alias typeFilter, U) if(!is(U == struct) && !is(U == class) && 
											!isPointer!U && !isArray!U && 
											!is(U == enum) && !is(U == function) &&
											!is(U == delegate))
{
	alias T = FullyUnqual!U;

	static void pass0() 
	{
		if(assembly.findInfo!T) return;

		RTTI rtti;
		rtti.name	  = T.stringof;
		rtti.fullyQualifiedName = fullyQualifiedName!(T);
		rtti.type	  = RTTI.Type.primitive;
		rtti.size	  = T.sizeof;

		rtti.assembly			= &assembly;
		rtti.offset				= ushort.max;
		rtti.hash				= typeHash!T;		
		addRTTI!T(rtti);
	}
}

template MetaTypeData(alias typeFilter, U) if(is(U == function) || is(U == delegate))
{
	void pass0() 
	{
		//Do nothing for now!
	}
}

template MetaTypeData(alias typeFilter, U) if(is(U == struct) || is(U == class))
{
	alias Atribs = TypeTuple!(__traits(getAttributes, U));
	alias T = FullyUnqual!U;

	static if(typeFilter!T && staticIndexOf!(DontReflect, Atribs) == -1)
	{

		alias filteredMethods		= Filter!(not!isConstructor, Methods!T);
		alias filteredFunctions		= Functions!T;
		alias filteredConstructors  = Filter!(isConstructor, Methods!T);

		void pass0()
		{
			if(assembly.findInfo!T) return;

			MetaType type;
			type.assembly   = &assembly;
			type.rttiOffset = cast(ushort)assembly.rttis.length;

			RTTI rtti;
			rtti.name	  = T.stringof;
			rtti.fullyQualifiedName = fullyQualifiedName!(T);
			rtti.offset   = cast(ushort)assembly.types.length;
			rtti.assembly = &assembly;
			rtti.hash				= typeHash!T;	
			static if(is(T == class)) {
				rtti.size = __traits(classInstanceSize, T);
				rtti.type = RTTI.Type.class_;
			} else {
				rtti.size = T.sizeof;
				rtti.type = RTTI.Type.struct_;
			}


			static if(isGeneric!T)
			{
				foreach(arg; TemplateArgsOf!T)
				{
					static if(is(arg))
					{
						MetaTypeData!(typeFilter, arg).pass0();
					}
				}

				rtti.isGeneric = true;
				static if(__traits(compiles, () => rttiOffset!(TemplateArgsOf!(T)[0])))
				{
					rtti.innerOffset   = rttiOffset!(TemplateArgsOf!(T)[0]);
				}

				static if(__traits(compiles, () => rttiOffset!(TemplateArgsOf!(T)[1])))
				{
					rtti.innerOffset2   = rttiOffset!(TemplateArgsOf!(T)[1]);
				}
			}
	

			auto idx = assembly.types.length;
			addRTTI!T(rtti);
			assembly.types ~= type;


			foreach(i; staticIota!(0, T.tupleof.length))
			{
				alias attributes = TypeTuple!(__traits(getAttributes, T.tupleof[i]));
				MetaTypeData!(typeFilter, typeof(T.tupleof[i])).pass0();
			}

			alias sFields = StaticFields!(T);
			foreach(i; staticIota!(0, sFields.length))
			{
				MetaTypeData!(typeFilter, typeof(sFields[i])).pass0();
			}

			foreach(i, m;  filteredMethods)
			{
				MetaTypeData!(typeFilter, ReturnType!m).pass0();
				foreach(p; ParameterTypeTuple!(m))
				{
					MetaTypeData!(typeFilter, p).pass0();
				}
			}

			foreach(i, m;  filteredFunctions)
			{
				MetaTypeData!(typeFilter, ReturnType!m).pass0();
				foreach(p; ParameterTypeTuple!(m))
				{
					MetaTypeData!(typeFilter, p).pass0();
				}
			}

			foreach(i, e; Enums!T)
			{
				MetaTypeData!(typeFilter, e).pass0();
			}

			foreach(i, s; Structs!(T))
			{
				MetaTypeData!(typeFilter, s).pass0();
			}

			foreach(i, s; Classes!(T))
			{
				MetaTypeData!(typeFilter, s).pass0();
			}

			pass1(assembly.types[idx]);
		}

		void pass1(ref MetaType type)
		{
			type.methodsInterval = TinyInterval(assembly.methods.length, filteredMethods.length);
			foreach(i, m;  filteredMethods)
				assembly.methods ~= makeMethod!(T, m)(type.rttiOffset);

			type.functionsInterval = TinyInterval(assembly.functions.length,
												  filteredFunctions.length);

			foreach(i, m; filteredFunctions) 
				assembly.functions  ~= makeFunction!(m);

			type.instanceFieldsInterval = TinyInterval(assembly.instanceFields.length,
													   T.tupleof.length);
			alias ifields = InstanceFields!(T);
			foreach(i; staticIota!(0, ifields.length))
				assembly.instanceFields ~= makeField!(i)(type.rttiOffset);

			type.staticFieldsInterval = TinyInterval(assembly.staticFields.length,
													 StaticFields!(T).length);

			alias fields = StaticFields!(T);
			foreach(i; staticIota!(0, fields.length))
			{
				assembly.staticFields  ~= makeField!(Identifier!(fields[i]));
			}

			type.constructorsInterval = TinyInterval(assembly.constructors.length,
													 filteredConstructors.length);
			foreach(i, ctor; filteredConstructors)
				assembly.constructors  ~= makeConstructor!(ctor)(type.rttiOffset);

			type.attributesInterval = makeAttributes!(__traits(getAttributes, T));
		}

		auto makeField(uint i)(ushort ownerOffset)
		{
			enum name = T.tupleof[i].stringof;
			InstanceMetaField f;
			f.name		         = name;
			f.assembly           = &assembly;
			f.offset	         = T.tupleof[i].offsetof; 
			f.fieldInfoOffset    = rttiOffset!(typeof(T.tupleof[i]));
			f.ownerOffset        = ownerOffset;
			f.attributesInterval = makeAttributes!(__traits(getAttributes, T.tupleof[i]));
			f.modifier	         = GetModifier!(typeof(T.tupleof[i]));
			return f;
		}

		auto makeField(string s)()
		{
			alias field = TypeTuple!(__traits(getMember, T, s));

			StaticMetaField f;
			f.name	             = s;
			f.fullyQualifiedName = fullyQualifiedName!field;
			f.field              = &field[0];
			f.assembly           = &assembly;
			f.fieldInfoOffset    = rttiOffset!(typeof(field[0]));
			f.attributesInterval = makeAttributes!(__traits(getAttributes, field[0]));
			f.modifier           = GetModifier!(typeof(field[0]));

			return f;
		}

		MetaMethod makeMethod(T, alias func)(ushort ownerTypeOffset)
		{
			import dll.error;

			MetaMethod m;
			m.name	             = Identifier!func;
			m.assembly		     = &assembly;

			alias returnType = ReturnType!func;
			alias paramTypes = ParameterTypeTuple!func;
			static if(is(T == struct)) 
			{
				T t = T.init;
				static if(isConstructor!(func)) 
					alias ref returnType delegate(paramTypes) d;
				else 
					alias returnType delegate(paramTypes) d;

			} else 
			{
				alias returnType delegate(paramTypes) d;
				T t  = cast(T)(typeid(T).init.ptr);
			}

			m.funcptr		     = &wrap!(func, T);
			m.hash			     = typeHash!(d); 
			m.returnOffset		 = rttiOffset!(ReturnType!func);
			m.ownerOffset	     = ownerTypeOffset;
			m.attributesInterval = makeAttributes!(__traits(getAttributes, func));

			alias ptype = ParameterTypeTuple!(func);
			alias pids  = ParameterIdentifierTuple!(func);

			auto interval = TinyInterval(assembly.parameters.length, ptype.length);

			foreach(i, paramType; ptype) {
				MetaParameter p;
				p.assembly = &assembly;
				p.name = pids[i];
				p.rttiOffset = rttiOffset!(paramType);
				assembly.parameters ~= p;
			}
			m.parametersInterval = interval;

			return m;
		}

		MetaConstructor makeConstructor(alias ctor)(uint rttiOffset)
		{
			import std.conv;
			alias paramTypes = ParameterTypeTuple!ctor;
			static if(is(T == class))
			{
				alias func_t = T function(paramTypes);
			}
			else 
			{
				alias func_t = ref T function(paramTypes);
			}

			MetaConstructor c;
			c.assembly			 = &assembly;
			c.hash				 = typeHash!(void function(paramTypes));
			c.attributesInterval = makeAttributes!(__traits(getAttributes, ctor));
			c.parametersInterval = makeParameters!(ctor);
			c.funcptr			 = &construct!(paramTypes);
			c.ownerOffset		 = .rttiOffset!(T);
			return c;
		}

		void construct(Params...)(void[] memory, Params args)
		{
			import std.conv;
			emplace!(T)(memory, args);
		}

	}
	else 
	{
		void pass0() { }
	}
		
}

auto makeParameters(alias func)()
{
	alias ptype = ParameterTypeTuple!(func);
	alias pids  = ParameterIdentifierTuple!(func);

	auto interval = TinyInterval(assembly.parameters.length, ptype.length);

	foreach(i, paramType; ptype) {
		MetaParameter p;
		p.assembly = &assembly;
		p.name = pids[i];
		p.rttiOffset = rttiOffset!(paramType);
		assembly.parameters ~= p;
	}

	return interval;
}

auto makeAttributes(Attribs...)()
{
	auto interval = TinyInterval(assembly.attributes.length, 
								 Attribs.length);

	foreach(i, attribute; Attribs) {
		//Check to see that the attribute has a value.
		static if(is(attribute))
		{
			assembly.attributes ~= MetaAttribute.create(attribute.init);
		}
		else static if(__traits(compiles, typeof(attribute))) {
			assembly.attributes ~= MetaAttribute.create(attribute);
		} else {
			static assert(0, "Only value attributes are allowed!");
		}
	}

	return interval;
}

template GetModifier(T)
{
	static if(     is(T U == const U))      enum GetModifier = Modifier.const_;
	else static if(is(T U == immutable U))  enum GetModifier = Modifier.immutable_;
	else static if(is(T U == shared U))     enum GetModifier = Modifier.shared_;
	else                                    enum GetModifier = Modifier.mutable;
}

template FactoryFilter(alias func)
{
	template helper(string s) {
		enum helper = s != func.name;
	}

	alias filteredFunctions = TypeTuple!("factory");
	alias FactoryFilter = allSatisfy!(helper, filteredFunctions);
}

template ConstructorFilter(alias func)
{
	template helper(string s) {
		enum helper = s != func.name;
	}

	alias filteredFunctions = TypeTuple!("__ctor");
	alias FactoryFilter = allSatisfy!(helper, filteredFunctions);
}	

template StructReflectionFilter(alias func) 
{
	template helper() { enum helper = true; }
	alias StructReflectionFilter = helper;
}

template isStatic(alias func)
{
	enum isStatic = func.isStatic;
}

template and(alias first, alias second)
{
	template helper(alias func)
	{
		enum helper = first!(func) && second!(func);
	}

	alias and = helper;
}

template not(alias first)
{
	template helper(alias func)
	{
		enum helper = !first!(func);
	}

	alias not = helper;
}

template isConstructor(alias func)
{
	enum isConstructor = Identifier!(func) == "__ctor";
}

template isGeneric(T)
{
	enum isGeneric = Identifier!T != T.stringof;
}

template isStaticCtor(alias T)
{
	import std.algorithm, std.string;
	enum s = "_staticCtor";
	enum isStaticCtor = Identifier!T.startsWith(s);
}

template isTrue(alias func) { enum isTrue = true; }
