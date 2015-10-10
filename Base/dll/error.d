module dll.error;
version(Windows)
{
	alias errorHandler_t = void function(string);

	//2kb of error data
	__gshared char[1024 * 2] errorData;
	__gshared errorHandler_t errorHandler;
	__gshared string thrown;

	void defaultHandler(string msg)
	{
		import log;
		thrown = msg;
	}

	bool wasError()
	{
		return thrown.length != 0;
	}

	void throwError()
	{
		import std.exception;
		__gshared static Exception e = new Exception("");
		e.msg = thrown;
		thrown = null;

		throw e;
	}

	__gshared static this()
	{
		errorHandler = &defaultHandler;
	}

	auto wrap(alias F)() 
	{

		import std.traits;
		static auto ref wrapped(ParameterTypeTuple!F params)
		{
			try
			{
				auto ptr = &F;
				return ptr(params);			
			}
			catch(Throwable t)
			{
				import log;
				logInfo("Error while calling function: ", Identifier!F);

				import allocation, std.format, collections.list;
				List!char errors = List!char(errorData.ptr, 0, 1024 * 10);
				formattedWrite(&errors, "%s", t);
				errorHandler(cast(string)errors.array);				
			}

			static if(!is(ReturnType!F == void))
			{
				return ReturnType!F.init;
			}
		}

		return &wrapped;
	}

	import std.traits;
	import util.traits;
	auto ref wrap(alias D, T)(void* ptr, ParameterTypeTuple!D params) if(is(T == struct))
	{
		try
		{
			T* self = cast(T*)ptr;
			mixin("return self." ~ Identifier!D ~ "(params);");
		}
		catch(Throwable t)
		{
			import log;
			logInfo("Error while calling delegate: ", Identifier!T, ".", Identifier!D);

			import allocation, std.format, collections.list;
			List!char errors = List!char(errorData.ptr, 0, 1024 * 10);
			formattedWrite(&errors, "%s", t);
			errorHandler(cast(string)errors.array);	
		}
		
	

		static if(is(ReturnType!D == void))
			return;
		else
		{
			//This value is garbage anyways!
			return *cast(ReturnType!D*)(ptr);
		}
	}
}
else 
{
	auto wrap(alias F)() 
	{
		auto ptr = &F;
		return ptr;
	}

	auto wrap(alias D, T)()
	{
		T* self;
		mixin("return self." ~ Identifier!D ~ "(params);");
	}
}