module screens.risk_screen;

public import app.screen;
public import rendering.shapes;
public import rendering.combined;
public import content : AsyncContentLoader, AtlasHandle, FontHandle;
public import graphics;
public import data;
public import event_queue;
public import eventmanager;
public import network_manager;

class RiskScreen : Screen
{
	RiskState*					riskState;
	EventManager*				riskEvents;
	NetworkEventManager*		network;
	FontHandle					fonts;
	AtlasHandle					atlas;
	string						title;

	this(bool blockUpdate, bool blockRender) { super(blockUpdate, blockRender); } 

	override void initialize() 
	{
		riskState     = app.locate!(RiskState);
		riskEvents    = app.locate!(EventManager);
		network	      = app.locate!(NetworkEventManager);

		auto loader = app.locate!(AsyncContentLoader);
		load(*loader);

		atlas = loader.load!TextureAtlas("Atlas");
		fonts = loader.load!FontAtlas("Fonts");
	}

	override void render(Time time) 
	{
		auto renderer = app.locate!(Renderer2D);
		import window.window;
		auto wnd = app.locate!Window;

		auto font = fonts["consola"];

		float2 size = font.measure(title) * float2(75,75);
		float2 pos  = float2(wnd.size.x / 2 - size.x / 2, wnd.size.y - size.y);

		renderer.begin();
		renderer.drawText(title, pos, float2(75, 75), font, Color.white, float2(0.35, 0.65));
		render(time, *renderer);
		renderer.end();
	}

	void load(ref AsyncContentLoader loader) { }
	void render(Time time, ref Renderer2D renderer) { }
}