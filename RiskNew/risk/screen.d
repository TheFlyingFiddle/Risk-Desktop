module risk.screen;

import app.screen;
import risk.states.common;
import risk.states.rendering;
import risk.states.start;
import allocation;

class RiskScreen : Screen
{
	RenderContext rContext;
	Board		  board;
	GameChannel   input, output;

	IGameState[GameStates.max] states;
	GameStates[GameStates.max] transitions;
	GameStates current;

	this(IAllocator allocator, string boardFile) 
	{ 
		super(false, false);

		RenderSettings s;
		 s.unitAtlas		= "Atlas";
		s.countryAtlas		= "Atlas";
		s.fonts				= "Fonts";
		s.pixel				= "pixel";
		s.titleFont			= "consola";

		rContext = RenderContext(s, this.app);
		board	 = Board.load(allocator, boardFile);
		input	 = GameChannel(allocator);
		output	 = GameChannel(allocator);

		current						  = GameStates.start;
		states[GameStates.start]	  = allocator.allocate!(Start)(allocator, &board);

		//Transitions.		
		transitions[GameStates.start] = GameStates.build;
	}

	override void initialize() 
	{
	}

	override void update(Time time) 
	{
		if(states[current].hasCompleated)
		{
			states[current].exit(output);
			current = transitions[current];
			states[current].enter(output);
		}

		states[current].handleInput(input);
		states[current].update(time, output);
	}

	override void render(Time time) 
	{
		rContext.renderer.begin();
		states[current].render(time, rContext);
		rContext.renderer.end();
	}
}