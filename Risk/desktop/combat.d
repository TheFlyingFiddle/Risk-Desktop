module desktop.combat;

import desktop.risk;
import graphics.font;
import collections;
import std.algorithm;

enum PreparationState
{
	placeUnits,
	attackUnits,
	fighting
}

class DesktopCombatScreen : Screen
{
	uint turn;
	uint slot;
	PlayerID[2] players;

	CountryID country;


	RiskState* state;
	NetworkEventManager* network;
	Mouse*				 mouse;

	PreparationState pstate;
	UnitID[3][2]	 placed;
	uint[3][2]		 attacks;


	this() { super(false, false); }
	override void initialize() 
	{
		state = app.locate!(RiskState);
		network = app.locate!(NetworkEventManager);

		this.mouse = app.locate!(Mouse);

		initUnits();
		initAttacks();
		slot = 0;
		turn = 0;
		pstate = PreparationState.placeUnits;
	}

	void initUnits()
	{
		static initialUnits   = [UnitID.init, UnitID.init, UnitID.init]; 
		foreach(ref placements; placed)
		{
			placements[] = initialUnits;
		}	
	}

	void initAttacks()
	{
		static initialAttacks = [uint.max, uint.max, uint.max];
		foreach(ref a; attacks)
		{
			a[] = initialAttacks;
		}
	}

	override void update(Time time) 
	{
		import window.window;
		auto wnd = app.locate!(Window);

		while(network.outgoing.canReceive())
		{
			network.outgoing.receive(
			(PlayerID player, UnitDeath d)
			{
				uint p = players[0] == player ? 0 : 1;
				placed[p][d.slot] = UnitID.init;
				pstate = PreparationState.placeUnits;
			},
			(PlayerID player, CombatResult result)
			{
				owner.remove(this);
			},	
			(NetworkEvent e) { });
		}

		if(pstate == PreparationState.placeUnits)
		{
			if(allUnitsPlaced()) 
			{
				slot = 0;
				if(turn == 1)
					pstate = PreparationState.attackUnits;
				else 
					slot = 0;

				turn = (turn + 1) % 2;
				return;
			}

			while(placed[turn][slot] != UnitID.init)
			{
				slot++;
				if(slot == placed[turn].length)
					return;
			}
		}
		else if(pstate == PreparationState.attackUnits) 
		{
			if(placed[turn].length == slot)
			{
				network.incomming.send(players[turn], PlayerDone());
				turn = (turn + 1) % 2;
				slot = 0;

				if(turn == 0)
				{
					initAttacks();
					pstate = PreparationState.fighting;	
				}
				return;
			}

			while(placed[turn][slot] == UnitID.init)
			{
				slot++;
				if(slot == placed[turn].length)
					return;
			}
		}

		if(mouse.wasPressed(MouseButton.left))
		{
			if(pstate == PreparationState.placeUnits)
			{
				float2 start = turn == 0 ? float2(40, wnd.size.y * 0.75) : 
										   float2(wnd.size.x - 90, wnd.size.y * 0.75);
				foreach(i, unit; state.desc.units)
				{
					Rect bounds = Rect(start, start + 50);
					if(bounds.contains(mouse.location) && canPosition(unit.id))
					{
						network.incomming.send(players[turn], PositionUnit(unit.id, slot));
						placed[turn][slot++] = unit.id;
					}

					start.y -= 60;
				}
			} 
			else 
			{
				float2 left  = float2(wnd.size.x / 2 - 200, wnd.size.y / 2 + 75);
				float2 right = float2(wnd.size.x / 2 + 200, wnd.size.y / 2 + 75);
				
				float2 hostile  = turn == 0 ? right : left;
				uint other = (turn + 1) % 2;
				foreach(i; 0 .. attacks[other].length) 
				{
					if(placed[other][i] != UnitID.init)
					{
						Rect bounds = Rect(hostile, hostile + 50);
						if(bounds.contains(mouse.location))
						{
							network.incomming.send(players[turn], AttackUnit(slot, i));
							attacks[turn][slot++] = i; 
						}
					}

					hostile.y -= 100;
				}
			}
		}
		else 
		{
			//Don't really do anthing here
		}
	}

	bool canPosition(UnitID id)
	{
		int numUnits = state.board.units.count!(x => x.id == id &&
												x.location == country &&
											    x.ruler    == players[turn]);
		numUnits -= placed[turn][0 .. slot].count!(x => x == id);
		return numUnits > 0;
	}

	bool allUnitsPlaced()
	{
		auto numUnits = state.board.units.count!(x => 
												 x.location == country &&
												 x.ruler    == players[turn]);
		auto scount   = placed[turn][].count!(x => x != UnitID.init);

		return slot == placed[turn].length || numUnits - slot == 0 || scount == placed[turn].length || scount == numUnits;
	}
}