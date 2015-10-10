module content.content;

import std.traits, 
	allocation, 
	collections,
	util.hash,
	std.path,
	content.textureatlas,
	std.algorithm;

struct Handle
{
	HashID hashID;
	TypeHash typeHash;
	void* item;
}

struct ContentHandle(T)
{
	private Handle* handle;
	this(Handle* handle)
	{
		this.handle = handle;
	}

	@property ref T asset()
	{
		enum h = typeHash!T;
		assert(handle.typeHash == h);
		auto item = cast(T*)(handle.item);
		return *item;
	}

	@property HashID resourceID()
	{
		return handle.hashID;
	}

	alias asset this;
}

struct FileLoader
{
	TypeHash typeHash;
	string extension;

	void* function(IAllocator, string, bool) load; 
	void  function(IAllocator, void*) unload;
}

FileLoader makeLoader(Loader, string ext)()
{
	import std.traits;
	alias T = ReturnType!(Loader.load);
	alias BaseT = typeof(*T);
	static assert(is(ParameterTypeTuple!(Loader.unload)[1] == T), "Wrong item type for unloader!");

	static void* load(IAllocator all, string path, bool async)
	{
		return cast(void*)Loader.load(all, path, async);
	}

	static void unload(IAllocator all, void* item)
	{
		Loader.unload(all, cast(T)item);
	}

	FileLoader loader;
	loader.typeHash  = typeHash!BaseT;
	loader.extension = ext;
	loader.load		 = &load;
	loader.unload	 = &unload;
	return loader;
}


//This should not be done.
//Will change when Editor resource system
//Is more stable.
//Used during debuging :)
struct Dependencies
{
	string name;
	string[] deps;
}
struct FileMap
{
	Dependencies[] dependencies;
}

struct ContentLoader
{
	List!FileLoader fileLoaders;
	IAllocator allocator;
	string resourceFolder;
	Handle[] items;

	int resourceCount;
	FileMap avalibleResources; //Temporary hack.

	this(A)(ref A allocator, IAllocator itemAllocator, 
			size_t maxResources, string resourceFolder)
	{
		items = allocator.allocate!(Handle[])(maxResources);
		items[] = Handle.init;

		this.allocator = itemAllocator;
		this.resourceFolder = resourceFolder;
		
		//We will not have more the 100 file formats.
		this.fileLoaders   = List!(FileLoader)(allocator, 100);
		this.resourceCount = 0;

		//Temporary hack! <- Don't do this!
		import std.file;
		import content.sdl, util.strings;
		auto f = text1024(resourceFolder, "\\FileCache.sdl");
		if(exists(f))
		{
			avalibleResources = fromSDLFile!(FileMap)(allocator, f); 
		}
	}

	void addFileLoader(FileLoader fileLoader)
	{
		this.fileLoaders ~= fileLoader;
	}

	private size_t indexOf(HashID hash) nothrow
	{
		auto index = items.countUntil!(x => x.hashID == hash);
		return index;
	}

	private uint addItem(T)(HashID hash, T* item)
	{
		return addItem(hash, typeHash!T, cast(void*)item);
	}

	private size_t addItem(HashID hash, TypeHash typeHash, void* item)
	{
		foreach(i, ref handle; items)
		{
			if(handle.item is null) {
				items[i] = Handle(hash, typeHash, item);
				resourceCount++;
				return i;
			}
		}

		assert(0, "Resources full!");
	}

	private ContentHandle!T getItem(T)(HashID hash) nothrow
	{
		ContentHandle!T handle  = ContentHandle!T(&items[indexOf(hash)]);
		return handle;
	}

	Handle* getItem(HashID hash) nothrow 
	{
		return &items[indexOf(hash)];
	}

	Handle* getItem(string path) nothrow
	{
		return getItem(bytesHash(path));
	}
	
	bool isLoaded(string path) nothrow 
	{
		return isLoaded(bytesHash(path));
	}

	bool isLoaded(HashID hash) nothrow
	{
		scope(failure) return false;
		return indexOf(hash) != -1;
	}

	Handle* load(string path)
	{
		import std.path, util.strings;
		auto ext = path.extension;
		auto hash = bytesHash(path[0 .. $ - ext.length]);
		if(isLoaded(hash)) return getItem(path[0 .. $ - ext.length]);

		auto fileLoader = fileLoaders.find!(x => x.extension == ext)[0];
		auto file		= text1024(resourceFolder, dirSeparator, hash.value, ext);
		void* loaded    = fileLoader.load(allocator, cast(string)file, false);

		auto itemIndex	= addItem(hash, fileLoader.typeHash, loaded);
		return &items[itemIndex];
	}

	Handle* load(TypeHash typeHash, string path)
	{
		auto hash = bytesHash(path);
		if(isLoaded(hash)) 
		{
			auto item = items[indexOf(hash)];
			assert(item.typeHash == typeHash);
			return getItem(hash);
		}

		import util.strings;

		auto index = fileLoaders.countUntil!(x => x.typeHash == typeHash);
		assert(index != -1, "Can't load the type specified! " ~ path);

		auto loader = fileLoaders[index];
		auto file = text1024(resourceFolder, dirSeparator, hash.value,  loader.extension);
		void* loaded   = loader.load(allocator, cast(string)file, false);
		auto itemIndex = addItem(hash, typeHash, loaded);
		
		return getItem(hash);
	}

	ContentHandle!(T) load(T)(string path)
	{
		return ContentHandle!(T)(load(typeHash!T, path));
	}

	bool unload(T)(ContentHandle!(T) cHandle)
	{
		auto handle = cHandle.handle;
		if(handle.item is null) return false;
		return unloadItem(handle.hashID);
	}

	private bool unloadItem(HashID hash)
	{
		auto index  = indexOf(hash);
		auto item   = items[index];

		auto loader = fileLoaders.find!(x => x.typeHash == item.typeHash)[0];
		loader.unload(allocator, item.item);
		items[index] = Handle.init;

		resourceCount--;
		return true;
	}

	private void change(HashID hash, TypeHash typeHash, void* item)
	{
		auto handle = items[indexOf(hash)];
		auto fileLoader = fileLoaders.find!(x => x.typeHash == handle.typeHash)[0];
		fileLoader.unload(allocator, handle.item);

		auto loaded = &items[indexOf(hash)];
		assert(loaded.typeHash == typeHash);
		loaded.item = item;
	}	

	@disable this(this);
}

struct ContentConfig
{
	size_t maxResources;
	string resourceFolder;
}

struct AsyncContentLoader
{
	enum maxNameSize = 25; //Assumes 11bytes for hash and 14bytes for extension

	import concurency.task;

	private ContentLoader loader;
	private int numRequests;	

	string resourceFolder() { return loader.resourceFolder; }
	FileMap avalibleResources() { return loader.avalibleResources; }

	this(A)(ref A allocator, ContentConfig config)
	{
		this(allocator, config.maxResources, config.resourceFolder);
	}

	this(A)(ref A allocator, size_t numResources, string resourceFolder)
	{
		import content : createStandardLoader;
		loader = createStandardLoader(allocator, Mallocator.cit, numResources, resourceFolder);
		numRequests = 0;
	}
	
	Handle* load(TypeHash hash, string path)
	{
		return loader.load(hash, path);
	}

	Handle* load(string path)
	{
		return loader.load(path);
	}

	ContentHandle!(T) load(T)(string path)
	{
		return loader.load!T(path);
	}

	void unload(T)(ContentHandle!T handle)
	{
		loader.unload(handle);
	}

	void reload(HashID hash)
	{
		import util.strings;
		auto index = loader.indexOf(hash);
		if(index != -1)
		{
			auto item       = loader.items[index];
			auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == item.typeHash)[0];

			enum maxNameSize = 25; //Assumes 11bytes for hash and 14bytes for extension

			auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
			auto absPath = text(buffer, loader.resourceFolder, dirSeparator, hash.value, fileLoader.extension);
			numRequests++;

			
			taskpool.doTask!(asyncLoadFile)(cast(string)absPath, hash, fileLoader, &addReloadedAsyncFile);	
		}
	}

	void asyncLoad(T)(string path)
	{
		if(loader.isLoaded(path)) return;


		import std.algorithm, util.strings;
		import concurency.threadpool;
		import concurency.task;

		auto fileLoader = loader.fileLoaders.find!(x => x.typeHash == typeHash!T)[0];
		auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
		auto absPath = text(buffer, loader.resourceFolder, dirSeparator, bytesHash(path).value, fileLoader.extension);
		
		auto adder = &addAsyncItem;

		numRequests++;
		taskpool.doTask!(asyncLoadFile)(cast(string)absPath, bytesHash(path), fileLoader, adder);			   
		
	}

	void asyncLoad(string path)
	{
		import std.path, util.strings;
		auto ext = path.extension;
		auto hash = bytesHash(path[0 .. $ - ext.length]);
		if(loader.isLoaded(hash)) return;


		auto fileLoader = loader.fileLoaders.find!(x => x.extension == ext)[0];
		auto buffer = Mallocator.it.allocate!(char[])(loader.resourceFolder.length + maxNameSize);
		auto absPath = text(buffer, loader.resourceFolder, dirSeparator, hash.value, ext);
		auto adder = &addAsyncItem;

		numRequests++;
		taskpool.doTask!(asyncLoadFile)(cast(string)absPath, hash, fileLoader, adder);
	}

	private void addAsyncItem(HashID hash, TypeHash typeHash, void* item)
	{
		loader.addItem(hash, typeHash, item);
		numRequests--;
	}


	private void addReloadedAsyncFile(HashID hash, TypeHash typeHash, void* item)
	{
		loader.change(hash, typeHash, item);
		numRequests--;
	}

	bool isLoaded(string path)
	{
		return loader.isLoaded(path);
	}	

	bool areAllLoaded()
	{
		return numRequests == 0;
	}

	Handle* getItem(string path) nothrow
	{
		return loader.getItem(path);
	}

	ContentHandle!T item(T)(string path) nothrow
	{
		return loader.getItem!T(bytesHash(path));
	}
}

void asyncLoadFile(string path, HashID hash, FileLoader loader, void delegate(HashID, TypeHash, void*) adder) 
{
	import log;
	logInfo("Loading file: ", path);

	import concurency.task;
	auto item = loader.load(Mallocator.cit, path, true);
	auto t = task(adder, hash, loader.typeHash, item);
	doTaskOnMain(t);
	Mallocator.it.deallocate(cast(void[])path);
}