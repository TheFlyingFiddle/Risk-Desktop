module math.rect;
import math.vector;

struct Rect
{
	float x, y, w, h;
	this(float x, float y, float w, float h)
	{
		this.x = x; this.y = y;
		this.w = w; this.h = h;
	}

	this(float2 start, float2 end)
	{
		import std.math : abs;
		import std.algorithm : min, max;
		this.x = min(start.x, end.x);
		this.y = min(start.y, end.y);
		this.w = abs(start.x - end.x);
		this.h = abs(start.y - end.y);
	}

	this(float4 f)
	{
		this(f.x, f.y, f.z - f.x, f.w - f.y);
	}

	alias toFloat4 this;

	float4 toFloat4()
	{
		return float4(x, y, x + w, y + h);
	}

	bool contains(float2 point)
	{
		return x < point.x &&  x + w > point.x &&
			y < point.y &&  y + h > point.y;
	}

	bool intersects(Rect other)
	{
		return !(other.left > this.right || 
				 other.right < this.left ||
				 other.top < this.bottom ||
				 other.bottom > this.top);

	}

	void displace(float2 offset)
	{
		this.x += offset.x;
		this.y += offset.y;
	}

	static Rect empty() { return Rect(0,0,0,0); }

	const void toString(scope void delegate(const(char)[]) sink)
	{
		import util.strings;
		char[100] buffer;
		sink(text(buffer, "X:", x, " Y:", y, "W:", w, "H:", h));
	}	

	float left() { return x; }
	float right() { return x + w; }
	float top() { return y + h; }
	float bottom() { return y; }
}