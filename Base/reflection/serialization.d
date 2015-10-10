module reflection.serialization;

import content.sdl;
import util.hash;
import util.variant;
import util.traits;

import reflection.data;		
import allocation;
import std.algorithm;

struct ReflectionContext
{
	const(MetaAssembly*)[] assemblies;
	U read(U, C)(SDLIterator!(C)* iter) if(is(U == VariantTable!(32)))
	{
		auto all = iter.allocator;	
		auto index = iter.currentIndex;
		auto len   = iter.walkLength;
		U table = U(all, len);

		iter.goToChild();
		foreach(i; 0 .. len)
		{
			auto obj = iter.over.root[iter.currentIndex];
			auto next = obj.nextIndex;
			auto name = iter.readName();

			auto object = iter.as!(VariantN!(32));
			table.add(name, object);
			iter.currentIndex = next;
		}

		return table;
	}

	U read(U, C)(SDLIterator!(C)* iter) if(is(U == VariantN!N, size_t N))
	{
		static if(is(U == VariantN!N, size_t N))
		{
			iter.goToChild();

			auto old = iter.currentIndex;
			iter.goToNext("type");
			auto id = iter.readString();
			iter.currentIndex = cast(ushort)old;
			iter.goToNext("value");

			const(RTTI)* info;
			foreach(a; assemblies)
			{
				info = a.findInfo(id);
				if(info)
					break;
			}

			assert(info, "Cannot find reflection info for type " ~ id ~ ".");
			assert(info.size <= N - 4, "Cannot deserialize large object " ~ info.name);

			VariantN!(N) object = info.initial!(N)();
			readMetaInfo(iter, info, object.data.ptr);
			return object;
		}
	}

	void readMetaInfo(C)(SDLIterator!(C)* iter, in RTTI* info, void* store)
	{
		import std.typetuple;
		import std.algorithm;
		alias primitives = TypeTuple!(ubyte,  byte, 
									  ushort, short, 
									  uint,   int,
									  ulong,  long,
									  float,  double, 
									  real, bool);

		final switch(info.type) with(RTTI.Type)
		{
			case primitive:
				foreach(p; primitives)
				{
					if(p.stringof == info.name)
						*cast(p*)store = iter.as!p;
				}
				break;
			case struct_:
				if(info.name.startsWith("GrowingList"))
				{
					auto data  =  readArray(iter, info.inner);
					*cast(void**)store							  = data.ptr;
					*cast(size_t*)(store + size_t.sizeof)		  = data.length / info.inner.size;
					*cast(size_t*)(store + size_t.sizeof * 2)	  = data.length / info.inner.size;

					//This needs to be fixed imho
					*cast(IAllocator*)(store + size_t.sizeof * 3) = cast(IAllocator)Mallocator.cit;
				
				}
				else if(info.name.startsWith("List"))
				{
					auto data  =  readArray(iter, info.inner);
					*cast(void**)store						  = data.ptr;
					*cast(size_t*)(store + size_t.sizeof)     = data.length / info.inner.size;
					*cast(size_t*)(store + size_t.sizeof * 2) = data.length / info.inner.size;
				}
				else if(info.name.startsWith("VariantN"))
				{
					iter.goToChild();
					auto old = iter.currentIndex;
					iter.goToNext("type");
					auto id = iter.readString();
					iter.currentIndex = cast(ushort)old;
					iter.goToNext("value");

					const(RTTI)* inner;
					foreach(a; assemblies)
					{
						inner = a.findInfo(id);
						if(inner)
							break;
					}

					assert(info, "Cannot find reflection info for type " ~ id);
					auto tmp = cast(ubyte*)store;
					tmp[0 .. inner.size] = (cast(ubyte*)inner.defaultValue)[0 .. inner.size];

					readMetaInfo(iter, inner, store);
					auto ptr_ = store + info.size - TypeHash.sizeof;
					*cast(TypeHash*)(ptr_) = TypeHash(bytesHash(id));
				}
				else 
				{
					readMetaStruct(iter, info.metaType, store);
				}
				break;
			case array:
				//Strings are handled diffrently!
				if(info.name == "char[]")
				{
					auto str  = iter.as!(char[]);
					*cast(size_t*)(store) = str.length;
					*cast(void**)(store + size_t.sizeof) = str.ptr;
				}
				else 
				{
					auto data = readArray(iter, info.inner);
					*cast(size_t*)(store) = data.length / info.inner.size;
					*cast(void**)(store + size_t.sizeof) = data.ptr;
				}
				break;
			case pointer:	
				//Does not work for null pointers yet!
				//auto data = iter.allocator.allocateRaw(info.inner.size, 4);
				//readMetaInfo(iter, info.inner, data.ptr);
				//*cast(void**)store = data.ptr;
				break;
			case enum_:
				auto enumType = info.metaEnum;
				auto enumVal = iter.as!(char[]);
				bool found = false;
				foreach(ref constant; enumType.constants)
				{
					if(constant.name == enumVal)
					{
						*cast(uint*)store = constant.value;
						found = true;
						break;
					}
				}
				assert(found, "The enum " ~ info.fullyQualifiedName ~ " does not have a value " ~ enumVal ~ ".");
				break;
			case class_:
				assert(0, "Cannot deserialize class " ~ info.fullyQualifiedName);
		}
	}

	void[] readArray(C)(SDLIterator!(C)* iter, in RTTI* info)
	{
		auto listLength = iter.walkLength;
		auto data       = iter.allocator.allocateRaw(listLength * info.size, 4);
		iter.goToChild();


		foreach(i; 0 .. listLength) {
			auto obj =  iter.over.root[iter.currentIndex];
			auto next = obj.nextIndex;

			readMetaInfo(iter, info, &data[i * info.size]);
			iter.currentIndex = next;
		}


		return data;
	}

	void readMetaStruct(C)(SDLIterator!(C)* iter, const(MetaType)* s, void* store)
	{
		iter.goToChild();
		auto first =  iter.currentIndex;
		foreach(field; s.instanceFields) 
		{
			try 
			{
				iter.goToNext(field.name); 
				readMetaInfo(iter, field.typeInfo, store + field.offset);
			}
			catch(Exception e)
			{
				import log;
				logInfo("Failed to find item ", s.typeInfo.name, ".", field.name);
				logInfo(e);
			}

			iter.currentIndex = first;
		}
	}

	void write(U, Sink)(ref U u, ref Sink sink, int level) if(is(U == VariantTable!(N), size_t N))
	{
		import std.range;

		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectOpener);

		foreach(key, ref value; u)
		{
			sink.put('\n');
			sink.put('\t'.repeat(level));

			bool found = false;
			sink.put(key);
			sink.put(" = ");
			toSDL(value, sink, &this, level + 1);
		}

		sink.put('\n');
		sink.put('\t'.repeat(level - 1));
		sink.put(objectCloser);
	}

	void write(U, Sink)(ref U u, ref Sink sink, int level) if(is(U == VariantN!N, size_t N))
	{
		import std.range;
		
		const(RTTI)* info;
		foreach(a; assemblies)
		{
			info = a.findInfo(u.id);
			if(info)
				break;
		}
		
		if(info)
		{
			writeVariant!Sink(info, u.data.ptr, sink, level);
		}
		else 
		{
			assert(0, "Cannot serialize variant since it contains a type without reflection information!");
		}
	}

	void writeVariant(Sink)(const(RTTI)* info, void* data, ref Sink sink, int level)
	{
		sink.put("\n");
		sink.put('\t'.repeat(level - 1));
		sink.put(objectOpener);
		sink.put("\n");
		sink.put('\t'.repeat(level));
		sink.put("type = ");
		toSDL(info.fullyQualifiedName,sink, &this, level);
		sink.put("\n");
		sink.put('\t'.repeat(level));
		sink.put("value = ");
		writeMetaInfo!Sink(info, data, sink, level + 1);
		sink.put("\n");
		sink.put('\t'.repeat(level - 1));
		sink.put("}");
	}

	void writeMetaInfo(Sink)(const(RTTI)* info, void* value, ref Sink sink, int level)
	{
		alias primitives = TypeTuple!(ubyte,  byte, 
									  ushort, short, 
									  uint,   int,
									  ulong,  long,
									  float,  double, 
									  real, bool);

	    final switch(info.type) with(RTTI.Type)
		{
			case primitive:
				foreach(p; primitives)
				{
					if(p.stringof == info.name)
					{
						toSDL(*cast(p*)value, sink, &this, level + 1);
					}
				}
				break;
			case struct_:
				if(info.name.startsWith("List") || 
				   info.name.startsWith("GrowingList"))
				{
					auto ptr = *cast(void**)&value[0];
					auto len = *cast(size_t*)&value[size_t.sizeof] * info.inner.size;
					writeMetaArray!Sink(info.inner, ptr[0 .. len], sink, level);
					break;
				}
				else if(info.name.startsWith("VariantN"))
				{
					auto ptr_ = value + info.size - TypeHash.sizeof;
					TypeHash hash = *cast(TypeHash*)(ptr_);

					VariantN!48 test = *cast(VariantN!(48)*)value;

					const(RTTI)* inner;
					foreach(a; assemblies)
					{
						inner = a.findInfo(hash);
						if(inner)
							break;
					}

					assert(inner, "Cannot serialize variant since it contains a type without reflection information!");


					writeVariant(inner, value, sink, level);
				}
				else 
				{
					writeMetaStruct!Sink(info.metaType, value, sink, level);
				}
				break;
			case array:
				auto len = *cast(size_t*)&value[0] * info.inner.size;
				auto ptr = *cast(void**)&value[size_t.sizeof];

				//Strings are handled diffrently!
				if(info.name == "char[]")
				{
					toSDL(cast(char[])ptr[0 .. len], sink, &this, level);
				}
				else 
				{
					writeMetaArray!Sink(info.inner, ptr[0 .. len], sink, level);
				}
				break;
			case pointer:

				toSDL("null", sink, &this, level);
				//Need to work for null pointers before we can make use of this.
				//auto ptr = *cast(void**)value;
				//writeMetaInfo(info.inner, ptr, sink, level);
				break;
			case enum_:
				auto enumType = info.metaEnum;
				auto enumVal = *cast(uint*)value;
				bool found = false;
				foreach(ref constant; enumType.constants)
				{
					if(constant.value == enumVal)
					{
						sink.put(constant.name);
						found = true;
						break;
					}
				}

				import util.strings;
				assert(found, text1024("The enum ",info.fullyQualifiedName," does not have a value of ",enumVal,"."));
				break;
			case class_:
				assert(0, "Cannot serialize class " ~ info.fullyQualifiedName);
		}
	}

	void writeMetaArray(Sink)(const(RTTI)* info,  void[] array, ref Sink sink, int level)
	{
		sink.put("\n");
		sink.put('\t'.repeat(level - 1));
		sink.put(arrayOpener);
		foreach(i; 0 .. array.length / info.size)
		{
			writeMetaInfo!Sink(info, &array[info.size * i], sink, level + 1);
			if(i != (array.length / info.size) - 1)
				sink.put(arraySeparator);
		}	

		sink.put("\n");
		sink.put('\t'.repeat(level - 1));
		sink.put(arrayCloser);
	}

	void writeMetaStruct(Sink)(const(MetaType)* s, void* value, ref Sink sink, int level)
	{
		if(level != 0) {
			sink.put('\n');
			sink.put('\t'.repeat(level - 1));
			sink.put(objectOpener);
		}

		foreach(field; s.instanceFields) {
			sink.put('\n');
			sink.put('\t'.repeat(level));
			sink.put(field.name);
			sink.put('=');
			writeMetaInfo!Sink(field.typeInfo, value + field.offset, sink, level + 1);
		}

		if(level != 0){
			sink.put('\n');
			sink.put('\t'.repeat(level - 1));
			sink.put(objectCloser);
		}
	}

}

unittest
{
	
	alias Variant = VariantN!(48);

	struct Test
	{
		Variant[] variants;
		Variant   variant;
		VariantTable!(32) map;
	}	

	string s = 
		q{
			variants = 
			[
				{ type = |int|		value = 3 }
				{ type = double		value = 23.3 }
				{ type = |List!int| value = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
				{ type = |int[]|    value = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
				{ type = |char[]|   value = |Hello There you in the hoodie!| }
				{ type = |TestB|    value = { a = 0 b = 3 d = |WEEEEE| } }
				{ type = |int*|     value = 7 }
			]

				variant = { type = |int| value = 3 }

			map =
			{
				first  = { type = int value = 3 }
				second = { type = double value = 23.3 } 
			}
		};


		import collections.list;
		ReflectionContext().read!(VariantN!(48), ReflectionContext)(null);
		
		//List!char writer;		
		Variant value0;
		VariantTable!(48) value1;
		import std.stdio;
		auto file = File("");
		auto writer = file.lockingTextWriter();
		ReflectionContext().write(value0, writer,  0);
		ReflectionContext().write(value1, writer,  0);
		
		
	
		//import tests;
		try
		{
			ReflectionContext c;
			c.assemblies = [&assembly];

			auto data = fromSDLSource!Test(Mallocator.it, s, c);

			assert(data.variants[0].get!int == 3);
			assert(data.variants[1].get!double == 23.3);
			assert(data.variants[2].get!(List!int).array == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
			assert(data.variants[3].get!(int[])          == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
			assert(data.variants[4].get!(char[]) == "Hello There you in the hoodie!");
		//	assert(data.variants[5].get!(TestB)  == TestB(0, 3, "WEEEEE"));
			assert(*data.variants[6].get!(int*)  == 7);

			assert(data.variant.get!(int) == 3);
			assert(data.map.first.get!(int) == 3);
			assert(data.map.second.get!(double) == 23.3);

			List!char store;
			store = List!char(Mallocator.it, 100000);
			//toSDL(data, store, &c);
			//logInfo(store.array);

			data = fromSDLSource!Test(Mallocator.it, cast(string)store.array, c);

		}
		catch(Throwable t)
		{
			import log;
			logInfo(t);
		}



		int dummy;
	
}