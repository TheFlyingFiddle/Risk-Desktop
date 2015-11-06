import std.stdio;
import sidal.parser;
import sidal.serializer;
import encoding.binary;
import std.range;
import std.array;
import std.datetime;
import allocation;

alias SR = SidalParser;
enum startData = "Coord[] coordinates = Coord[](";
enum endData   = ")\n\0"; 

char[] testString;
string terminatedString;
struct Player
{
	//string name;
	uint   hp, mana;
	uint   gold;
}

struct TestGenericChar
{
	char[] s;
	this(char[] s)
	{
		this.s = s;
	}

	char front() { return s[0]; }
	bool empty() { return s.length == 0; }
	void popFront() { s = s[1 .. $]; }
}
import std.algorithm;
struct TestGenericCharArray
{
	char[] s;
	this(char[] s)
	{
		this.s = s;
	}

	char[] front() { return s[0 .. min(1024, $)]; }
	bool empty() { return s.length == 0; }
	void popFront() { s = s[min(1024, $) .. $]; }
}

struct Coord
{
	float x = float.nan, y = float.nan, z = float.nan;
	//string name;
}

pragma(msg, Coord.sizeof);


void benchTokens()
{
	//ubyte[1024 * 64] buffer = void;
	//auto s = SidalDecoder(File("data2.txt", "rb").byChunk(buffer[]));
	//foreach(i; 0 .. 1000000)
	//{
	//    Player p = s.process!Player();
	//    //assert(p.name == "Looking good!");
	//    assert(p.hp   == 10);
	//    assert(p.mana == 20);
	//    assert(p.gold == 32);
	//}

	//SR r = SR(ByChunkRange(File("data.txt", "rb")), buffer);
//	auto parser = SR(File("data.txt", "rb"), buffer);
//	while(!parser.empty)
//	{
//		parser.popFront();
//	}
	import std.algorithm;
	auto coords =  decodeSIDAL!(Coord[])(File("data2.txt", "rb"), Mallocator.cit);
	coords.deallocate();
	//Uses default SidalDecoder. okok.
	//auto coords = decodeSIDAL!(Coord[])(File("data.txt", "rb"));

	//foreach(ref token; SR(FileSource(File("data.txt", "rb")), buffer)) 
	//foreach(ref token; SR(GenericRange(TestGenericCharArray(testString)), buffer)) 
	//foreach(ref token; SR(StringSource(testString), buffer))
	{
		//if(token.tag == TokenTag.type || 
		//   token.tag == TokenTag.name || 
		//   token.tag == TokenTag.ident || 
		//   token.tag == TokenTag.string)
		//    writeln(token.tag, " ", token.value.array);
		//else 
		//    writeln(token.tag);
	}
}

void benchBinary()
{
	import allocation;
	File f = File("data.dat", "rb");
	size_t s = cast(size_t)f.size();
	auto mem = Mallocator.it.allocateRaw(s, Coord.alignof);
	scope(exit) Mallocator.it.deallocate(mem);
	mem = f.rawRead(mem);
	assert(mem.length == s);

	Coord[] c;
	encoding.binary.decode(mem.ptr, c);
}

void benchWalktrhough()
{
	auto p = testString.ptr;
	while(true)
	{
		if(*p++ == '\0')
			break;
	}
}

int main(string[] argv)
{
	import std.file;

	import std.random;
	import std.format;
	testString ~= startData;
	Coord[] coords;
	foreach(i; 0 .. 1000000)
	{
		double x, y, z;
		x = uniform(0.000001, 1.0);
		y = uniform(0.000001, 1.0);
		z = uniform(0.000001, 1.0);
		testString ~= format("(%f,%f,%f),\n", x,y,z);
		coords ~= Coord(x, y, z);
	}

	testString = testString[0 .. $ - 2];
	testString ~= endData;
	testString = testString[0 .. $ - 1];


	//if(!exists("data2.txt"))
	{
		File f = File("data2.txt", "wb");
		f.rawWrite(testString);
	}

	//if(!exists("data.dat"))
	{
		File f = File("data.dat", "wb");
		auto store = TestStore();
		store.encode(coords);
		f.rawWrite(store.data);
	}


	size_t size = cast(size_t)File("data2.txt", "rb").size() / 1024 / 1024;
	size_t size2 = cast(size_t)File("data.dat", "rb").size() / 1024 / 1024;
	writeln("Sidal Data Size: ", size, "mb");
	writeln("Binary Data Size: ", size2, "mb");

	//while(true)
	{
		StopWatch sw;

		sw.start();
		benchTokens();
		sw.stop();
		uint sidal_msecs = cast(uint)sw.peek.msecs;
		sw.reset();

		sw.start();
		benchBinary();
		sw.stop();
		uint binary_msecs = cast(uint)sw.peek.msecs;
		sw.reset();

		//sw.start();
		//benchWalktrhough();
		//sw.stop();
		import core.memory;
		GC.collect();

		writeln("Sidal took:    ", sidal_msecs, "	",  cast(uint)(size / (sidal_msecs /  1000.0)), " mb/s");
		writeln("Binary took:   ", binary_msecs, "   ", cast(uint)(size2 / (binary_msecs / 1000.0)), " mb/s");
		//writeln("Walkthrough:   ", sw.peek.msecs, "	",  cast(uint)(size / (sw.peek.msecs /  1000.0)), " mb/s");
		//writef("Sidal was %s times slower then walkthrough\n", cast(double)sidal_msecs / cast(double)sw.peek.msecs);
	}

	readln;
	return 0;
}

