module util.test;

import std.conv;
import util.traits;

enum Tag;

@Tag struct A 
{
	int a, b, c;
	__gshared int d;
	enum e = "hello";

	struct baz { int foo; string bar; }
}

struct B { }
@Tag struct C { }

@Tag class D 
{
	int a, b, c;
	__gshared int d;
	enum e = "hello";

	struct baz { int foo; string bar; }
}

class E { }

@Tag class F { }

unittest
{
	foreach(s; Structs!(util.test).That!(HasAttribute!Tag))
	{
		pragma(msg, "struct " ~ s.id);
		foreach(field; s.fields.all)
			pragma(msg, field.type.stringof ~ " " ~ field.id ~ " "~ field.offset.to!string);

		foreach(c; s.constants.all)
			pragma(msg, "enum " ~ c.type.stringof ~ " = " ~ c.value);

		foreach(field; s.sfields.all)
			pragma(msg, "static " ~ field.type.stringof ~ " " ~ field.id);

		foreach(sub; Structs!(s.type).all)
			pragma(msg, "substruct " ~ sub.id);
	}

	pragma(msg, "----");

	foreach(c; Classes!(util.test).That!(HasAttribute!Tag))
		pragma(msg, c.id);
}