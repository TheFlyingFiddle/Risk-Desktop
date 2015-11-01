import std.stdio;
import sidal.parser;
//import sidal.serializer;
import std.range;
import std.array;
import std.datetime;


alias SR = SidalRange;
enum startData = "float3[] coordinates = float3[](";
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

	char[1024 * 16] buffer = void;
	//SR r = SR(ByChunkRange(File("data.txt", "rb")), buffer);
	foreach(ref token; SR(FileSource(File("data.txt", "rb")), buffer)) 
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
	foreach(i; 0 .. 1000000)
	{
		double x, y, z;
		x = uniform(0.000001, 1.0);
		y = uniform(0.000001, 1.0);
		z = uniform(0.000001, 1.0);
		testString ~= format("(x=%f,y=%f,z=%f,name=\"abcde\",opts=1),", x,y,z);
	}

	testString = testString[0 .. $ - 1];
	testString ~= endData;
	testString = testString[0 .. $ - 1];

	if(!exists("data.txt"))
	{
		File f = File("data.txt", "wb");
		f.rawWrite(testString);
	}


	size_t size = testString.length / (1024 * 1024);
	writeln("Data Size: ", size, "mb");

	while(true)
	{
		StopWatch sw;

		sw.start();
		benchTokens();
		sw.stop();
		uint sidal_msecs = cast(uint)sw.peek.msecs;

		sw.reset();

		sw.start();
		benchWalktrhough();
		sw.stop();

		writeln("Sidal took:    ", sidal_msecs, "	",  cast(uint)(size / (sidal_msecs /  1000.0)), " mb/s");
		writeln("Walkthrough:   ", sw.peek.msecs, "	",  cast(uint)(size / (sw.peek.msecs /  1000.0)), " mb/s");
		writef("Sidal was %s times slower then walkthrough\n", cast(double)sidal_msecs / cast(double)sw.peek.msecs);
	}

	readln;
	return 0;
}

