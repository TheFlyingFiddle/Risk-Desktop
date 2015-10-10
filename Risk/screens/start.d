module screens.start;
import screens.risk_screen;
import util.strings;
import events; 
import network_events;
import std.random;

enum StartState
{
	start,
	mapLoaded,
	missionsAccepted
}

class GameStartScreen : RiskScreen
{
	Screen     next;
	StartState state;

	this(Screen next) 
	{ 
		super(false, false); 
		this.next = next;
		this.state = StartState.start;
		this.title = "Select Your Missions!";
	}

	override void load(ref AsyncContentLoader loader)
	{
		assignCountries();
		sendMissions();
	}

	void assignCountries()
	{
		auto countries = riskState.desc.countries;
		countries.randomShuffle();

		auto players   = riskState.board.players;
		auto step      = countries.length / players.length;
		foreach(i, player; players)
		{
			foreach(j; 0 .. step)
			{
				import std.stdio;
				size_t idx = i * step + j;
				riskEvents.enque(AssignCountry(player.id, countries[idx].id));
			}
		}

		foreach(i; step * players.length .. countries.length)
		{
			auto idx = uniform(0, players.length);
			riskEvents.enque(AssignCountry(players[idx].id, countries[i].id));
		}
	}

	void sendMissions()
	{

		auto missions = riskState.desc.missions;
		missions.randomShuffle();

		foreach(i, player; riskState.board.players)
		{
			network.outgoing.send(player.id, EnterState(InputState.selectMission));
			foreach(j; 0 .. 3)
			{
				size_t idx = i * 3 + j;
				network.outgoing.send(player.id, SendMission(missions[idx].id, missions[idx].description));	
			}
		}
	}

	bool missionsAccepted()
	{
		foreach(player; riskState.board.players)
		{
			if(player.mission == MissionID.init)
				return false;
		}

		return true;
	}

	void sendMoney()
	{
		foreach(player; riskState.board.players)
		{
			riskEvents.enque(GiveMoney(player.id, 10));
			network.outgoing.send(player.id, SendMoney(10));
		}
	}

	override void update(Time time)
	{		
		//Wait for input here.
		while(network.incomming.canReceive())
		{
			network.incomming.receive(
			(PlayerID id, MissionAccepted ma) 
			{
				riskEvents.enque(AssignMission(id, ma.id));
			},
			(NetworkEvent e) //default case not optional
			{
				import log;
				logInfo("Got unrecognised event");
			});
		}

		//Check if we are done with the mission phase!
		if(missionsAccepted())
		{
			sendMoney();
			owner.replace(this, next);
		}
	}

	
}

