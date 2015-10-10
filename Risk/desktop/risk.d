module desktop.risk;

public import app.screen;
public import rendering.shapes;
public import rendering.combined;
public import content : AsyncContentLoader, AtlasHandle, FontHandle;
public import graphics;
public import data;
public import event_queue;
public import eventmanager;
public import network_manager;
public import window.mouse;
public import window.keyboard;
public import network_events;

class DesktopRiskScreen : Screen
{
	RiskState*					riskState;
	NetworkEventManager*		network;
	Mouse*						mouse;
	Keyboard*					keyboard;
	FontHandle					fonts;
	AtlasHandle					atlas;
	uint turn;

	this() 
	{ 
		super(false, false);
	} 

	override void initialize() 
	{
		turn = 0;
		riskState     = app.locate!(RiskState);
		network	      = app.locate!(NetworkEventManager);
		mouse		  = app.locate!(Mouse);
		keyboard	  = app.locate!(Keyboard);

		auto loader = app.locate!(AsyncContentLoader);
		load(*loader);

		atlas = loader.load!TextureAtlas("Atlas");
		fonts = loader.load!FontAtlas("Fonts");
	}


	Player* player() 
	{
		return &riskState.board.players[turn];
	}

	final void nextTurn()
	{
		turn++;
		if(turn == riskState.board.players.length)
			lastTurn();
	}

	void lastTurn() 
	{
		owner.remove(this);
	}


	override void render(Time time) 
	{
		auto renderer = app.locate!(Renderer2D);
		auto font   = fonts["consola"];

		import util.strings;
		auto text = text1024("Player ", player.id.id, "'s turn");

		import window.window;
		auto wnd = app.locate!(Window);

		renderer.begin();
		float2 fsize = float2(50,50);
		float2 size  = font.measure(text) * fsize;
		float2 pos   = float2(wnd.size.x - size.x, 5);

		renderer.drawText(text, pos, fsize, font, player.color);
		render(time, *renderer);
		renderer.end();
	}

	void load(ref AsyncContentLoader loader) { }
	abstract void render(Time time, ref Renderer2D renderer);
}