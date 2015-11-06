
struct A { float x, y, z ,w, a; }
struct B 
{ 
	float x=float.nan; 
	float y=float.nan;
	float z=float.nan;
	float w=float.nan;
	float a=float.nan;
}

void initVal(T)(ref T t, ref float k) { pragma(inline, false); }

void benchA()
{
	foreach(float f; 0 .. 1000_000)
	{
		A val = A.init;
		initVal(val, f);
	}
}

void benchB()
{
	foreach(float f; 0 .. 1000_000)
	{
		B val = B.init;
		initVal(val, f);
	}
}

int main(string[] argv)
{
	import std.datetime;
	import std.stdio;

	auto res = benchmark!(benchA, benchB)(1);
	writeln("Default:  ", res[0]);
	writeln("Explicit: ", res[1]);

	readln;
    return 0;
}
