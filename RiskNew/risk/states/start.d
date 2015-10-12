module risk.states.start;

import risk.states.common;
import std.algorithm;
import risk.states.rendering;
import allocation;
import std.random;
import risk.database_operations;
import risk.output, risk.input;

class Start : GameState
{
	struct Mission
	{
		PlayerID player;
		MissionID mission;
	}

	List!(Mission) missions;
	this(IAllocator a, Board* data) 
	{ 
		super(data); 
		missions = List!(Mission)(a, 100);
	} 
	
	override void enter(ref GameChannel output) 
	{
		auto countries = board.countryDescs;
		auto players   = board.players; 
		
		//This is very questionable behaviour. 
		countries.randomShuffle();

		auto step      = countries.length / players.length;
		foreach(i, player; players)
		{
			foreach(j; 0 .. step)
			{
				import std.stdio;
				size_t idx = i * step + j;
				board.assignCountry(player.id, countries[idx].id);
			}
		}

		foreach(i; step * players.length .. countries.length)
		{
			auto idx = uniform(0, players.length);
			board.assignCountry(players[i].id, countries[idx].id);
		}

		auto m = board.missionDescs;
		m.randomShuffle();
		foreach(i, player; players)
		{
			output.send(player.id, SendEnterState(InputState.selectMission));
			foreach(j; 0 .. 3)
			{
				size_t idx = i * 3 + j;
				missions ~= Mission(player.id, m[idx].id);
				output.send(player.id, SendMission(m[idx].id, m[idx].description));	
				
			}
		}
	}
		
	override void handleInput(ref GameChannel input) 
	{
		while(!input.empty)
		{
			input.receive(
			(PlayerID id, MissionAccepted ma)
			{
				if(!missions.find!(x => x.player == id && x.mission == ma.id).length)
					return;

				board.assignMission(id, ma.id);
				missions = std.algorithm.remove!(x => x.player == id)(missions);
			});
		}
	}
	
	override bool hasCompleated() 
	{
		return missions.length == 0;
	}
		
	override void render(Time time, ref RenderContext context) 
	{
		context.drawTitle("Select Your Missions!");
		context.drawCountries(board);
		context.drawUnits(board);
	}
}