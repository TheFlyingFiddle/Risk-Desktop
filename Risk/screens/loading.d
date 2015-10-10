module screens.loading;

import app.screen;
import content;
import rendering;
import rendering.combined;

struct LoadingConfig
{
	bool loadAll;
	string[] toLoad;
	string font;
}

class LoadingScreen : Screen
{
	LoadingConfig config;
	FontHandle font;
	AsyncContentLoader* loader;
	Screen[] next;

	this(LoadingConfig config, Screen[] next)
	{
		super(false, false);
		this.config = config;
		this.next   = next;
	}

	override void initialize()
	{
		import content;
		loader = app.locate!AsyncContentLoader;
		font = loader.load!FontAtlas(config.font);

		if(config.loadAll)
		{
			foreach(ref item; loader.avalibleResources.dependencies)
			{
				loader.asyncLoad(item.name);
			}
		}
		else 
		{
			foreach(item; config.toLoad)
				loader.asyncLoad(item);
		}
	}

	override void update(Time time)
	{
		if(loader.areAllLoaded)
		{
			owner.remove(this);
			foreach(screen; next)
				owner.push(screen);
		}
	}

	uint frame = 0;
	override void render(Time time)
	{
		import std.range, util.strings, window.window;
		auto screen   = app.locate!Window;
		auto renderer = app.locate!Renderer2D;
		renderer.viewport(float2(screen.size));
		renderer.begin();

		frame++;

		string msg = cast(string)text1024("Loading", '.'.repeat(frame % 20));		
		renderer.drawText(msg, float2(0,0),float2(50,50), font.asset.fonts[0], Color.white, float2(0.4, 0.5));

		renderer.end();
	}
}