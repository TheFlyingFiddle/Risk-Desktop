module reflection.data;

import std.exception;
import util.traits;
import util.variant;
import util.hash;

__gshared static MetaAssembly assembly;

struct DontReflect { }

@DontReflect
struct MetaAssembly
{
	const(RTTI)* findInfo(T)() const
	{
		return findInfo(typeHash!T);
	}

	const(RTTI)* findInfo(string name) const
	{
		auto hash = bytesHash(name);
		auto p = hash in nameIndex;
		if(p)
			return &this.rttis[*p];

		p = hash in qualifiedNameIndex;
		if(p)
			return &this.rttis[*p];

		return null;
	}

	const(RTTI)* findInfo(TypeHash hash) const 
	{
		auto p = HashID(hash.value) in qualifiedNameIndex;
		if(p)
		{			
			return &this.rttis[*p];
		}

		return null;
	}

	package ushort[HashID] nameIndex;
	package ushort[HashID] qualifiedNameIndex;

	RTTI[]              rttis;
	MetaType[]          types;
	MetaEnum[]			enums;
	MetaConstant[]		constants;
	MetaMethod[]        methods;
	MetaFunction[]      functions;
	MetaParameter[]     parameters;
	MetaAttribute[]     attributes;
	MetaConstructor[]	constructors;
	StaticMetaField[]   staticFields;
	InstanceMetaField[] instanceFields;
	
}

@DontReflect
struct RTTI
{
	enum Type : ushort { class_, struct_, primitive, array, pointer, enum_ }

	MetaAssembly* assembly;
	string fullyQualifiedName;
	string name;
	TypeHash hash;

	void* defaultValue;

	Type type;
	//Should save a cached hash here alswell!

	//Offset is a bad name.
	ushort offset;
	ushort size;
	ushort alignment;

	//This is special
	bool isGeneric = false;
	ushort innerOffset;
	ushort innerOffset2;

	void initial(void[] store) const
	{
		store[0 .. size] = defaultValue[0 .. size];
	}

	VariantN!(N) initial(size_t N)() const
	{
		VariantN!N v;
		v.id = hash;
		v.data[0 .. size] = defaultValue[0 .. size];
		return v;
	}

	@property const(RTTI)* inner() const
	{
		enforce(type == Type.array || type == Type.pointer || isGeneric);
		return &assembly.rttis[innerOffset];
	}

	@property const(RTTI)* inner2() const
	{
		enforce(isGeneric);
		return &assembly.rttis[innerOffset2];
	}



	@property const(MetaType)* metaType() const
	{
		enforce(type == Type.class_ || type == Type.struct_);
		return &assembly.types[offset];
	}

	@property const(MetaEnum)* metaEnum() const
	{
		enforce(type == Type.enum_);
		return &assembly.enums[offset];
	}

	@property bool isTypeOf(T)() const
	{
		alias U = FullyUnqual!T;
		if(typeHash!U == hash)
		{
			return true;
		}

		return false;
	}	

	bool isTypeOf(Variant)(Variant v) const
	{
		return v.id == hash;
	}

	string toString()
	{
		import std.conv : to;
		return "RTTI(" ~ name ~ "," ~ type.to!string ~ ")";
	}
}

struct TinyInterval
{
	ushort offset;
	ushort count;

	this(size_t offset, size_t count)
	{
		assert(offset < ushort.max);
		assert(count  < ushort.max);

		this.offset = cast(ushort)offset;
		this.count  = cast(ushort)count;
	}
}

mixin template Interval(T, string name, string ident = name)
{
	enum intervalName = name ~ "Interval";
	mixin("TinyInterval " ~ intervalName ~ ";");
	mixin("@property " ~ T.stringof ~ "[] " ~ ident ~ "() nothrow {\n"
		  ~ "with(" ~ intervalName ~ ")\n" 
		  ~ "return assembly. " ~ name ~ " [offset .. offset + count];\n }");
	mixin("@property const(" ~ T.stringof ~ "[]) " ~ ident ~ "() const nothrow {\n"
		  ~ "with(" ~ intervalName ~ ")\n" 
		  ~ "return assembly. " ~ name ~ " [offset .. offset + count];\n }");

}

@DontReflect
struct MetaEnum
{
	MetaAssembly* assembly;

	ushort rttiOffset;
	mixin Interval!(MetaConstant, "constants");
}

@DontReflect
struct MetaConstant
{
	string name;
	uint   value; //Deal with other stuff laterz;
}

@DontReflect
struct MetaType
{
	MetaAssembly* assembly;
	ushort rttiOffset;

	@property const(RTTI)* typeInfo() const
	{
		return &assembly.rttis[rttiOffset];
	}

	@property bool isTypeOf(T)() const
	{
		return typeInfo.isTypeOf!T;
	}

	@property bool isTypeOf(V)(V v) const
	{
		return typeInfo.isTypeOf!V(v);
	}

	VariantN!N initial(size_t N)() const
	{
		return typeInfo.initial!N;
	}

	@property const(MetaMethod)* findMethod(string method)
	{
		foreach(ref m; methods)
		{
			if(m.name == method) return &m;
		}

		return null;
	}

	@property const(MetaFunction)* findFunc(string func)
	{
		foreach(ref f; functions)
		{
			if(f.name == func) return &f;
		}
		
		return null;
	}

	mixin Interval!(MetaConstructor,  "constructors");
	mixin Interval!(MetaFunction,	  "functions");
	mixin Interval!(MetaMethod,		  "methods");
	mixin Interval!(InstanceMetaField,"instanceFields");
	mixin Interval!(StaticMetaField,  "staticFields");
	mixin Interval!(MetaAttribute,	  "attributes");
}

@DontReflect
struct MetaMethod
{
	string name;
	TypeHash hash;
	MetaAssembly* assembly;
	void* funcptr;

	mixin Interval!(MetaAttribute, "attributes");
	mixin Interval!(MetaParameter, "parameters");

	ushort ownerOffset;
	ushort returnOffset;

	@property const(RTTI) ownerInfo() const
	{
		return assembly.rttis[ownerOffset];
	}

	@property const(RTTI) returnInfo() const
	{
		return assembly.rttis[returnOffset];
	}
}

auto ref invoke(R = void, Variant, Params...)(const(MetaType)* type, string name, ref Variant obj, auto ref Params params)
{
	auto p = tryBind!(R delegate(Params))(type, obj, name);
	if(p)
	{
		return p(params);
	}
	else 
	{
		enforce(0, "Failed to find method " ~ name);
		assert(0);
	}
}

auto ref invoke(R = void, Variant, Params...)(const(MetaMethod)* method, ref Variant obj, auto ref Params params) if(is(Variant v == Variant!N, N))
{
	enforce(obj.id == method.ownerInfo.hash);
	return invoke!(R, Params)(method, cast(void[])obj.mem[], params); 
}

auto ref invoke(R = void, Params...)(const(MetaMethod)* method, void[] mem,  auto ref Params params)
{
	alias R delegate(Params) del_t;
	enforce(typeHash!(del_t) == method.hash);

	alias R function(void*, Params) func_t;
	func_t fun = cast(func_t)method.funcptr;
	version(Windows)
	{
		import dll.error;
		static if(is(R == void))
			fun(mem.ptr, params);
		else 
			auto res = fun(mem.ptr, params);

		if(wasError())
		{
				throwError();
		}

		static if(!is(R == void))
			return res;
	}
	else 
	{
		return fun(obj.data.ptr, params);
	}
}

version(Windows)
{
	//Windows DLL's don't really work and 
	//in order to propagate exceptions we need
	//to do a bit of wrapping off the function calls.
	//This wrapping is done on both sides of the DLL
	//calls.
	struct Binding(D) if(is(D == delegate))
	{
		void* funcptr;
		void* context;

		alias R		 = ReturnType!D;
		alias Params = ParameterTypeTuple!D;

		this(void* funcptr, void* context)
		{
			this.funcptr = funcptr;
			this.context = context;	
		}

		alias isNotNull this;

		bool isNotNull()
		{
			return funcptr !is null;
		}

		static Binding!D bind(void* funcptr, void* context)
		{
			return Binding!D(funcptr, context);
		}

		R opCall(Params params)
		{
			alias R function(void*, Params) func_t;
			func_t fun = cast(func_t)funcptr;

			import dll.error;
			
			static if(is(R == void))
				fun(context, params);
			else 
				auto res  = fun(context, params);
			
			//Propagate exception!
			if(wasError())
				throwError();

			static if(is(R == void))
				return;
			else 
				return res;
		}
	}
}
else 
{
	template Binding(P) if(is(P == delegate))
	{
		alias Binding = P;
		P bind(P)(void* funcptr, void* context)
		{
			P p;
			p.ptr = context;
			p.funcptr = cast(typeof(p.funcptr))funcptr;
			return p;
		}
	}
}


Binding!P tryBind(P, V)(const(MetaType)* type, ref V variant, string methodName)
{
	foreach(m; type.methods)
	{
		if(m.name == methodName)
		{
			auto method = tryBind!(P,V)(&m, variant);
			if(method)
				return method;
		}
	}

	return Binding!P.init;
}

Binding!P bind(P, V)(const(MetaMethod)* method, ref V variant) if(is(P == delegate))
{
	enforce(variant.id == method.ownerInfo.hash);
	enum ptrHash = typeHash!(P)();
	enforce(ptrHash == method.hash);

	return Binding!(P).bind(cast(void*)method.funcptr, variant.data.ptr);
}

Binding!P tryBind(P, V)(const(MetaMethod)* method, ref V variant) if(is(P == delegate))
{
	if(variant.id != method.ownerInfo.hash) return Binding!P.init;
	if(typeHash!P != method.hash) return Binding!P.init;

	return Binding!(P).bind(cast(void*)method.funcptr, variant.data.ptr);
}


@DontReflect
struct MetaFunction
{
	string name;
	void* funcptr;
	MetaAssembly* assembly;
	TypeHash hash;
	ushort returnOffset;

	bool isType(Func)()
	{
		return typeHash!Func == hash;
	}

	mixin Interval!(MetaAttribute, "attributes");
	mixin Interval!(MetaParameter, "parameters");
}

R invoke(R = void, Params...)(const(MetaFunction)* func, Params params) 
{
	alias R function(Params) fun_t;
	enum hash = typeHash!(fun_t);
	enforce(hash == func.hash);

	auto fun = cast(fun_t)func.funcptr;
	version(Windows)
	{
		import dll.error;
		static if(is(R == void))
			fun(params);
		else 
			auto res = fun(mem.ptr, params);

		if(wasError())
		{
			//Basically if we are calling the function from the same library/dll/exe
			//We let the exception propagate normally.
			static immutable Exception e = new Exception("");
			if(func.assembly is &assembly)
			{
				//e.msg = text1024("Failed to excecute function : ", func.name);
				throw e;
			}
			else
				throwError();
		}

		static if(!is(R == void))
			return res;
	}
	else 
	{
		static if(is(R == void))
			fun(params);
		else
			return fun(params);
	}

}

@DontReflect
struct MetaConstructor
{
	string name;
	void* funcptr;
	MetaAssembly* assembly;

	TypeHash hash; 
	mixin Interval!(MetaAttribute, "attributes");
	mixin Interval!(MetaParameter, "parameters");
	ushort ownerOffset;

	@property const(RTTI) ownerInfo() const
	{
		return assembly.rttis[ownerOffset];
	}
}

VariantN!(N) create(size_t N = 32, Params...)(const(MetaType)* type, ref auto Params params)
{
	enum hash = typeHash!(void function(Params));
	foreach(ctor; type.constructors) {
		if(hash == ctor.hash) 
		{
			VariantN!N variant;
			variant.id = type.typeInfo.hash;
			ctor.createAt!(Params)(variant.data[], params);
			return variant;
		}
	}

	enforce(0, "Type " ~ type.typeInfo.name ~ 
			"does not contain a constructor taking parameters " ~ 
			Params.stringof ~ ".");
	assert(0);
}


void destroy(size_t N = 32)(const(MetaType)* type, ref VariantN!N obj)
{
	foreach(ref method; type.methods)
	{
		if(method.name == "__dtor")
		{
			(&method).invoke(obj);
		}
	}
}

void[] createNew(A, Params...)(const(MetaType)* type, ref A allocator, ref auto Params params)
{
	import allocation;

	auto info = type.typeInfo;
	enum hash = typeHash!(void function(Params));
	foreach(ctor; type.constructors) {
		if(hash == ctor.hash) 
		{
			void[] data = allocator.allocateRaw(info.size, info.alignment);
			createAt(ctor, data, params);
			return  data;
		}
	}

	enforce(0, "Type " ~ type.typeInfo.name ~ 
			"does not contain a constructor taking parameters " ~ 
			Params.stringof ~ ".");
	assert(0);
}


void createAt(Params...)(in MetaConstructor ctor, void[] buffer, ref auto Params params)
{
	enum hash = typeHash!(void function(Params));
	enforce(ctor.hash == hash);

	alias void function(void[], Params) initializer;
	auto init = cast(initializer)ctor.funcptr;

	init(buffer, params);
}


alias MetaAttribute = VariantN!(32);

bool hasAttribute(Attrib, T)(ref T item) nothrow
{
	foreach(attribute; item.attributes)
	{
		auto p = attribute.peek!(Attrib);
		if(p)
			return true;
	}

	return false;
}

Attrib getAttribute(Attrib, T)(ref T item) nothrow
{
	scope(failure) return Attrib.init;

	enum hash = typeHash!Attrib;
	foreach(attribute; item.attributes)
	{
		if(attribute.id == hash)
			return attribute.get!Attrib;
	}

	assert(0, "Could not find attribute of type " ~ Attrib.stringof ~ ".");
}

enum Modifier : ushort { immutable_, mutable, const_, shared_ }

@DontReflect
struct InstanceMetaField
{
	MetaAssembly* assembly;
	string name;
	mixin Interval!(MetaAttribute, "attributes");
	ushort offset;
	ushort ownerOffset;
	ushort fieldInfoOffset;

	Modifier modifier; 

	@property const(RTTI)* ownerInfo() const
	{
		return &assembly.rttis[ownerOffset];
	}

	@property const(RTTI)* typeInfo() const
	{
		return &assembly.rttis[fieldInfoOffset];
	}

	void set(V)(in RTObject obj, V value)
	{
		enforce(typeid(V) == fieldInfo.tinfo);
		enforce(obj.rtti == ownerInfo);
		enforce(modifier == Modifier.mutable);

		void* addr = obj.ptr + offset; 
		*cast(V*)addr =  value;
	}

	V get(V)(RTObject obj) 
	{
		enforce(typeid(V) == fieldInfo.tinfo);
		enforce(obj.rtti == ownerInfo);

		void* addr = obj.ptr + offset; 
		return *cast(V*)(addr);
	}
}

@DontReflect
struct StaticMetaField
{
	MetaAssembly* assembly;
	string name;
	string fullyQualifiedName;
	void* field;
	mixin Interval!(MetaAttribute, "attributes");

	ushort fieldInfoOffset;
	Modifier modifier; 

	@property const(RTTI)* fieldInfo() const
	{
		return &assembly.rttis[fieldInfoOffset];
	}

	void set(V)(V value)
	{
		enforce(fieldInfo.isTypeOf!V);
		enforce(modifier == Modifier.mutable);

		*cast(V*)field = value;
	}

	V get(V)()
	{
		enforce(fieldInfo.isTypeOf!V);
		return *cast(V*)field;
	}

	V* peek(V)()
	{
		if(fieldInfo.isTypeOf!V)
			return cast(V*)field;
		else 
			return null;
	}
}

@DontReflect
struct MetaParameter
{
	MetaAssembly* assembly;
	string name;
	ushort rttiOffset;

	@property const(RTTI)* typeInfo() const
	{
		return &assembly.rttis[rttiOffset];
	}
}