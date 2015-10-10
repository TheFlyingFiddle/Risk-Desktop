module content.sound;

import util.strings;
import sound;
import derelict.sdl2.mixer;
import allocation;

struct SoundID
{
	uint index;
}

struct SoundLoader
{
	static Sound* load(IAllocator allocator, string path, bool async)
	{
		import std.conv;
		auto c_path = path.toCString();
		auto sound = Mix_LoadWAV(c_path);
		if(!sound)
		{
			import log, std.c.string;
			const(char)* err = Mix_GetError();
			logErr("Mix_LoadWav: ", err[0 .. strlen(err)]);
		}

		assert(sound, text("Failed to load sound! ", c_path));
		return sound;
	}

	static void unload(IAllocator allocator, Sound* sound)
	{
		auto numChannels = Mix_AllocateChannels(-1);
		foreach(i; 0 .. numChannels)
		{
			auto chunk = Mix_GetChunk(i);
			if(chunk is sound)
			{
				Mix_HaltChannel(i);
			}
		}

		Mix_FreeChunk(sound);
	}
}