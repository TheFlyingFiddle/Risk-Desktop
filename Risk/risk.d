module risk;

import allocation;
import app.core;
import app.screen;
import collections;
import data;
import events;
import eventmanager;
import network_manager;
import screens.loading,
	   screens.world,
	   screens.start,
	   screens.build,
	   screens.move,
	   screens.attack;

class RiskComponent : IApplicationComponent
{
	RiskState state;
	EventManager events;
	NetworkEventManager netEvents;
	Screen				entry;

	this(A)(ref A alloc)
	{
		auto worldScreen	= alloc.allocate!(WorldScreen)();

		auto buildScreen    = alloc.allocate!(BuildScreen)(null);

		auto combatScreen   = alloc.allocate!(CombatScreen)();
		auto attackScreen   = alloc.allocate!(AttackScreen)(buildScreen, combatScreen);
		auto moveScreen		= alloc.allocate!(MoveScreen)(attackScreen);

		buildScreen.next    = moveScreen;
		auto startScreen	= alloc.allocate!(GameStartScreen)(buildScreen);
		entry			    = alloc.allocate!(LoadingScreen)(LoadingConfig(true, [], "Fonts"), cast(Screen[])[worldScreen, startScreen]);

		state	  = RiskState.init;
		events	  = EventManager(Mallocator.cit);	
		netEvents = NetworkEventManager(Mallocator.cit);
	}

	~this() { }

	override void initialize()
	{
		this.app.addService(&state);
		this.app.addService(&events);
		this.app.addService(&netEvents);

		auto s = app.locate!(ScreenComponent);
		s.push(entry);

		events.enque(LoadBoard("board.rmap"));
		events.enque(CreatePlayer(PlayerID(1), Color.blue, "Lukas"));
		events.enque(CreatePlayer(PlayerID(2), Color.red, "Gustav"));
		events.consumeEvents(state);
	}

	override void preStep(Time time) 
	{
		events.consumeEvents(state);
	}
}

import desktop.mission,
	   desktop.build,
	   desktop.move,
	   desktop.combat;

import network_events;
class DesktopNetworkComponent : IApplicationComponent
{
	NetworkEventManager* netEvents;
	HashMap!(InputState, Screen) screens;	
	DesktopCombatScreen combatScreen;

	this(A)(ref A alloc)
	{
		screens = HashMap!(InputState, Screen)(Mallocator.cit);

		//Desktop
		auto mission		= alloc.allocate!(MissionScreen)(Mallocator.cit);
		auto build			= alloc.allocate!(DesktopBuildScreen)();
		auto move			= alloc.allocate!(DesktopMoveScreen)();
		combatScreen		= alloc.allocate!(DesktopCombatScreen)();


		screens.add(InputState.selectMission, mission);
		screens.add(InputState.build, build);
		screens.add(InputState.move, move);
	}

	~this() { }

	override void initialize() 
	{
		netEvents = app.locate!NetworkEventManager;
	}

	override void preStep(Time time) 
	{
		auto outgoing = &netEvents.outgoing;
		while(outgoing.canReceive() 
		   && (outgoing.isEventType!(EnterState) ||
			   outgoing.isEventType!(SendMoney)  || 
			   outgoing.isEventType!(CombatStarted)))
		{
			outgoing.receive(
			(PlayerID p, EnterState e)
			{
				auto s = app.locate!(ScreenComponent);
				if(!s.has(screens[e.stateID])) 
				{
					s.push(screens[e.stateID]);
				}
			},
			(PlayerID p, CombatStarted cs)
			{
				auto s = app.locate!(ScreenComponent);
				if(!s.has(combatScreen))
				{
					combatScreen.players[0] = cs.defender;
					combatScreen.players[1] = cs.attacker;
					combatScreen.country    = cs.country;
					s.push(combatScreen);
				}
			},
			(NetworkEvent e) 
			{
				uint id;
			});
		}
	}
}