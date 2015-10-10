module io.file;

import std.stdio;
import allocation;


auto readText(A)(ref A allocator, const(char)[] file)
{
	auto f    = File(cast(string)file, "rb");
	auto data = cast(char[])allocator.allocateRaw(cast(size_t)f.size, (char[]).alignof);
	f.rawRead(data);

	return data;
}