module screens.move;

import screens.risk_screen;
import network_events;
import events;

class MoveScreen : RiskScreen
{
	uint numDone;
	Screen next;
	this(Screen next) 
	{ 
		super(false,false); 
		this.title = "Move Your Troops!";
		this.next  = next;
	}

	override void load(ref AsyncContentLoader loader) 
	{
		numDone = 0;
		foreach(player; riskState.board.players)
		{
			network.outgoing.send(player.id, EnterState(InputState.move));
		}
	}

	override void update(Time time) 
	{
		while(network.incomming.canReceive())
		{
			network.incomming.receive(
			(PlayerID player, UnitMoved um)
			{
				riskEvents.enque(MoveUnit(player, um.unit, um.from, um.to));
				//riskEvents.enque(PlaceUnit(pu.unit, pu.country, player));
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