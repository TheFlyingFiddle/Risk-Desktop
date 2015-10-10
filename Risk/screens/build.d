module screens.build;

import screens.risk_screen;
import network_events;
import events;
import std.algorithm;

class BuildScreen : RiskScreen
{
	uint numDone;
	Screen next;
	this(Screen next) 
	{ 
		super(false,false); 
		this.title = "Build Your Troops!";
		this.next  = next;
	}

	override void load(ref AsyncContentLoader loader) 
	{
		numDone = 0;
		foreach(player; riskState.board.players)
		{
			uint money = 0;
			money += riskState.board.countries.count!(x => x.ruler == player.id);
			foreach(continent; riskState.desc.continents)
			{
				if(continent.countries.all!(x => riskState.board.countries.find!(y => y.id == x && y.ruler == player.id).length > 0))
				{
					money += continent.bonus;
				}
			}
			
			riskEvents.enque(GiveMoney(player.id, money));
			network.outgoing.send(player.id, EnterState(InputState.build));
		}
	}

	override void update(Time time) 
	{
		while(network.incomming.canReceive())
		{
			network.incomming.receive(
			(PlayerID player, UnitPlaced pu)
			{
				import log;
				logInfo("Placing unit for player: ", player);
				riskEvents.enque(PlaceUnit(pu.unit, pu.country, player));
			},
			(PlayerID player, PlayerDone done)
			{
				numDone++;
			},
			(NetworkEvent e) { });
		}

		if(numDone == riskState.board.players.length)
		{
			owner.replace(this, next);
		}
	}
}