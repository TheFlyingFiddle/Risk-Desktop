module graphics.textureatlas;

import util.hash, collections.table, graphics.frame,
	   graphics.texture, math, std.algorithm;

struct SourceRect
{
	HashID hash;
	short4 source;
}

struct TextureAtlas
{
	Texture2D _texture;
	SourceRect[] rects;

	@property Texture2D texture()
	{
		return _texture;
	}
	
	size_t length()
	{
		return rects.length;
	}	

	bool contains(HashID id)
	{
		return rects.countUntil!(x => x.hash == id.value) != -1;
	}

	bool contains(string id)
	{
		return contains(bytesHash(id));
	}

	Frame opIndex(HashID id)
	{
		import std.algorithm;
		auto index = rects.countUntil!(x => x.hash == id.value);
		if(index != -1)
			return Frame(texture, rects[index].source);

		import util.strings;
		assert(0, text1024("Frame not present in atlas : ", id));
	}

	Frame opIndex(string name)
	{
		auto h = bytesHash(name);
		return this[h];
	}

	Frame opIndex(size_t index)
	{
		return Frame(_texture, rects[index].source);
	}

	Frame opDispatch(string s)()
	{
		return this[s];
	}

	
	size_t idToIndex(HashID id)
	{
		foreach(i; 0 .. rects.length)
		{
			if(rects[i].hash == id) 
				return i;
		}

		return -1;
	}

	HashID indexToID(size_t index)
	{
		return rects[index].hash;
	}

	int opApply(int delegate(size_t, Frame) dg)
	{
		int result;
		foreach(i; 0 .. rects.length)
		{
			result = dg(i, Frame(texture, rects[i].source));
			if(result) break;
		}
		return result;
	}
}