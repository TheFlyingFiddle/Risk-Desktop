module app.screen;

public import app.core;
import collections.list;

//Note to self use this enum.
enum ScreenLogic
{
	noBlock = 0,
	blockUpdate = 1,
	blockRender = 2,
	blockRenderAndUpdate = blockRender | blockRender
}

abstract class Screen
{
	private Application* _app; //Gives access to game. 
	@property Application* app() { return _app; }
	bool blockUpdate, blockRender;

	ScreenComponent owner() 
	{
		return app.locate!ScreenComponent;
	}

	this(bool blockUpdate, bool blockRender)
	{
		this.blockUpdate = blockUpdate;
		this.blockRender = blockRender;
	}	

	void initialize() { }
	void deinitialize() { }
	void update(Time time) { }
	void render(Time time) { }
}

final class ScreenComponent : IApplicationComponent
{
	private FixedList!Screen screens;

	this(A)(ref A allocator, size_t numScreens)
	{
		screens = FixedList!Screen(allocator, numScreens);
	}

	bool has(Screen screen)
	{
		import std.algorithm;
		return screens.find!(x => x == screen).length != 0;
	}

	void replace(Screen first, Screen second)
	{
		second._app = app;
		second.initialize();
		first.deinitialize();
		auto idx = screens.countUntil!(x => x == first);
		screens[idx] = second;
	}

	void remove(Screen screen)
	{
		screen.deinitialize();
		auto idx = screens.countUntil!(x => x == screen);
		if(idx != -1)
			screens.removeAt(idx);
	}

	void push(Screen screen)
	{
		screen._app = app;
		screen.initialize();
		screens ~= screen;
	}

	Screen pop()
	{
		assert(screens.length);

		auto r = screens[$ - 1];
		screens.length = screens.length - 1;
		r.deinitialize();
		return r;
	}

	override void step(Time time)
	{
		auto uIndex = screens.countUntil!(x => x.blockUpdate);
		auto rIndex = screens.countUntil!(x => x.blockRender);

		foreach(i, screen; screens)
		{
			int j = i;
			if(j >= uIndex)
				screen.update(time);
		}

		foreach(i, screen; screens)
		{
			int j = i;
			if(j >= rIndex)
				screen.render(time);
		}
	}
}