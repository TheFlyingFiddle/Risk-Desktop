module risk.states.common;

public import experimental.channel;
public import rendering.shapes,
			  rendering.combined;
public import app.core : Time;
public import risk.database;
public import risk.states.rendering;

enum GameStates
{
	start,
	build,
	move,
	attack,
	gameOver
}

alias GameChannel = Channel!(PlayerID);
interface IGameState
{
	bool hasCompleated();
	void enter(ref GameChannel output);
	void exit(ref GameChannel output);
	void handleInput(ref GameChannel input);
	void update(Time time, ref GameChannel output);
	void render(Time time, ref RenderContext context);
}

class GameState : IGameState
{
	Board* board;
	this(Board* board) { this.board = board; }

	abstract bool hasCompleated();
	abstract void enter(ref GameChannel output);
	abstract void render(Time t, ref RenderContext context);
	abstract void handleInput(ref GameChannel input);


	void exit(ref GameChannel output)		{ }
	void update(Time time, ref GameChannel output)	{ }
}

//I like this as this is better then classes. 
private mixin template Dispatch(To)
{
	alias T = typeof(this);
	To* parent;

	//We dispatch to the parent object like a baws.
	//Forwards all the stuff we want to parent.
	//This implies a few things. 
	//1. We need to write less code.
	//2. We need less space to store common data
	//3. We are not using global state which is good? 
	auto ref opDispatch(string s)()
	{
		static if(hasMember!(To, "s"))
		{
			static if(isCallable!(To.s))
				mixin("return parent." ~ s ~ "();");
			else
				mixin("return parent." ~ s ~ ";");
		}
		else
		{
			static assert(false, "RiskGame does not have a member called " ~ s ~ "!");
		}	
	}

	auto ref opDispatch(string s, Args...)(auto ref Args args) if(Args.length > 0)
	{
		static if(hasMember!(To, "s"))
		{
			mixin("return parent." ~ s ~ "(args);");
		}
		else
		{
			static assert(false, "RiskGame does not have a member called " ~ s ~ "!");
		}			
	}
}