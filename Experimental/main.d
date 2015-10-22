import std.stdio;
import sidal.parser;
//import sidal.serializer;
import std.range;
import std.array;
import std.datetime;

static string bigAssString = buildString();

string buildString()
{
	string s = "float3[] root = [";
	import std.random;
	import std.format;
	import std.conv;
	foreach(i; 0 .. 10000)
	{
		float a = 0.0, b = 1.0, c = 2.0;
		s ~= "(0.0, 1.0, 2.0),";
	}

	return s;
}

struct TestRange 
{
	@nogc nothrow:
	string front_;
	size_t count;
	this(string f) { this.front_ = f; count = 0; }

	char[] front() nothrow
	{
		return cast(char[])front_;
	}

	bool empty() nothrow { return count == 1000000; }

	void popFront() nothrow
	{
		count++;
	}
}

struct TestRange2
{
	@nogc nothrow:
	TestRange r;
	size_t offset;
	this(TestRange r) 
	{ 
		this.r = r;
	}

	char front() nothrow
	{
		return cast(char)r.front[offset];
	}

	bool empty() nothrow { return offset == 0 && r.empty; }

	void popFront() nothrow
	{
		if(offset == r.front.length - 1)
		{
			offset = 0;
			if(!r.empty)
				r.popFront();
		}
		else 
		{
			offset++;
		}

	}
}

alias SR = SidalRange;
enum startData = "float3[] coordinates = float3[](";
enum endData   = ")\n"; 

string testString;
string terminatedString;
struct Player
{
	//string name;
	uint   hp, mana;
	uint   gold;
}

import allocation;
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

	char[1024 * 64] buffer = void;
	SR r = SR(StringRange(testString), buffer);
	foreach(ref token; r) 
	{
		//if(token.tag == TokenTag.type || 
		//   token.tag == TokenTag.name || 
		//   token.tag == TokenTag.ident || 
		//   token.tag == TokenTag.string)
		//    writeln(token.tag, " ", token.value.array);
		//else 
		//    writeln(token.tag);
	}


	//s = SidalRange(BufferedRange(new TR("float2 f2 = float2(x = 10, y = 10)")));
	//while(!s.empty)
	//{
	//    auto f = s.front;
	//    f.visit!(
	//             (Start s)	=>  writeln(Start.stringof, s.type.array()),
	//             (End e)		=>  writeln(End.stringof),
	//             (Primitive p) => writeln(Primitive.stringof, p.token.tag),
	//             (Name n)	  => writeln(Name.stringof, n.name.array),
	//             (Variable v)  => writeln(Variable.stringof, v.type.array),
	//             (Ident i)     => writeln(Ident.stringof, i.ident.array))();
	//
	//    s.popFront();
	//}
}

__gshared int i = 0;
void benchWalktrhough()
{
	auto p = testString.ptr;
	while(true)
	{
		if(*p == '\0')
			break;
		p++;
	}
}

int main(string[] argv)
{
	import std.file;
	if(!exists("data2.txt"))
	{
		File f = File("data2.txt", "wb");
		foreach(i; 0 .. 10000000)
			f.writeln("Player root = Player(hp=10,mana=20,gold=32)");
	}

	/*
	x = []

	1000000.times do
	h = {
    'x' => rand,
    'y' => rand,
    'z' => rand,
    'name' => ('a'..'z').to_a.shuffle[0..5].join + ' ' + rand(10000).to_s,
    'opts' => {'1' => [1, true]},
	}
	x << h
	end

	File.open("1.json", 'w') { |f| f.write JSON.pretty_generate('coordinates' => x, 'info' => "some info") }
	*/

	import std.random;
	import std.format;
	testString = startData;
	foreach(i; 0 .. 1000000)
	{
		double x, y, z;
		x = uniform(0.000001, 1.0);
		y = uniform(0.000001, 1.0);
		z = uniform(0.000001, 1.0);
		testString ~= format("(x=%f,y=%f,z=%f,name=abcde,opts=1),", x,y,z);
	}
	testString = testString[0 .. $ - 1];
	testString ~= endData;

	size_t size = testString.length / (1024 * 1024);
	writeln("Data Size: ", size, "mb");

	StopWatch sw;

	sw.start();
	benchTokens();
	sw.stop();

	writeln("SidalProcessing took: ", sw.peek.msecs);
	writeln("Processed: ", cast(double)size / (cast(double)sw.peek.msecs /  1000.0));

	sw.reset();

	sw.start();
	benchWalktrhough();
	sw.stop();

	writeln("Walkthrough took: ", sw.peek.msecs);
	writeln("Processed: ", cast(double)size / (cast(double)sw.peek.msecs /  1000.0));



	readln;
	return 0;
}
