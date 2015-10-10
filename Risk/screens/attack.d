module screens.attack;

import screens.risk_screen;
import network_events;
import events;
import std.algorithm;

class AttackScreen : RiskScreen
{
	Screen		 next;
	CombatScreen combat;
	bool done;

	this(Screen next, CombatScreen combat) 
	{ 
		super(false,false); 
		this.title  = "Attacks Attacks Attacks!";
		this.next   = next;
		this.combat = combat;
	}

	override void load(ref AsyncContentLoader loader) 
	{
		done = false;
	}

	override void update(Time time) 
	{
		//Want to delay this one frame. 
		//We found no more attacks so the attack phase is over.
		if(done)
			this.owner.replace(this, next);

		auto b = riskState.board;
		foreach(country; b.countries)
		{
			auto hostile  = b.units.find!(x => x.location == country.id && x.ruler != country.ruler);
			//There are hostile units
			if(hostile.length)
			{
				import log;
				logInfo("Found conflict in country : ", country.id);
				auto friendly = b.units.find!(x => x.location == country.id && x.ruler == country.ruler);

				//There are friendly units so we have a battle!
				if(friendly.length)
				{	
					combat.country  = country.id;
					combat.attacker = hostile[0].ruler;
					combat.defender = friendly[0].ruler;
					this.owner.push(combat);
					return;
				}
				else 
				{
					riskEvents.enque(AssignCountry(hostile[0].ruler, country.id));
				}
			}	
		}

		done = true;
	}
}

enum CombatState
{
	preparing, 
	attack
}

class CombatScreen : Screen
{
	import collections;

	CountryID country;
	PlayerID  attacker, defender;
	
	RiskState* state;
	EventManager* events;
	NetworkEventManager* network;
	FontHandle	  		 fonts;
	AtlasHandle			 atlas;

	Slot[3] defSlots, attackSlots;
	bool attackerDone, defenderDone;
	CombatState combatState;

	struct Slot
	{
		UnitID unit;
		int   hp;
		int   ap;
		uint   toAttack;
	}
	
	this() 
	{ 
		super(true, true); 
	}

	override void initialize() 
	{
		state   = app.locate!(RiskState);
		events  = app.locate!(EventManager);
		network = app.locate!(NetworkEventManager);

		auto loader = app.locate!(AsyncContentLoader);
		atlas = loader.load!TextureAtlas("Atlas");
		fonts = loader.load!FontAtlas("Fonts");

		foreach(ref slot; defSlots)
			slot = Slot(UnitID.init, uint.max);

		foreach(ref slot; attackSlots)
			slot = Slot(UnitID.init, uint.max);

		attackerDone = defenderDone = false;
		combatState  = CombatState.preparing;

		foreach(player; state.board.players)
		{
			network.outgoing.send(player.id, CombatStarted(defender, attacker, country));
		}
	}

	override void update(Time time) 
	{
		//Check for combat over. 
		auto defenders = state.board.units.filter!(x => x.location == country && x.ruler == defender);
		auto attackers = state.board.units.filter!(x => x.location == country && x.ruler == attacker);

		auto defcount  = defenders.count();
		auto attcount  = attackers.count();

		//All defenders are dead
		if(defcount == 0 || attcount == 0)
		{
			//Attackers won
			if(attcount > 0) 
			{
				//We should give the attacker some money here
				events.enque(GiveMoney(attacker, 5));
				events.enque(AssignCountry(attacker, country));

				//We need to tell phone who won. 
				network.outgoing.send(attacker, CombatResult(true));
				network.outgoing.send(defender, CombatResult(false));
			}
			//Draw or defenders won
			else 
			{
				//Defenders are not rewarded on a win. 

				//We need to tell phone who won. 
				network.outgoing.send(attacker, CombatResult(false));
				network.outgoing.send(defender, CombatResult(true));
			}

			this.owner.remove(this);
		} 
		
		if(combatState == CombatState.preparing)
		{
			while(network.incomming.canReceive())
			{
				network.incomming.receive(
				(PlayerID player, PositionUnit pu)
				{
					auto unit = state.desc.units.find!(x => x.id == pu.unit)[0];
					Slot* slot = player == attacker ? &attackSlots[pu.slot] : & defSlots[pu.slot];
					slot.unit  = pu.unit;
					slot.hp    = unit.hp;
					slot.ap    = unit.attack;
				},
				(PlayerID player, AttackUnit au)
				{ 
					Slot* slot = player == attacker ? &attackSlots[au.fromSlot] : & defSlots[au.fromSlot];
					slot.toAttack = au.toSlot;
				},
				(PlayerID player, PlayerDone done)
				{
					if(player == attacker)
						attackerDone = true;
					if(player == defender)
						defenderDone = true;
				},
				(NetworkEvent e) { });
			}

			if(attackerDone && defenderDone)
			{
				combatState  = CombatState.attack;
				attackerDone = defenderDone = false;
			}
		}
		else if(combatState == CombatState.attack)
		{
			//Combat animations goes here. 
			foreach(ref slot; attackSlots) if(slot.unit != UnitID.init)
				defSlots[slot.toAttack].hp -= slot.ap;
			foreach(ref slot; defSlots) if(slot.unit != UnitID.init)
				attackSlots[slot.toAttack].hp -= slot.ap;

			foreach(i, ref slot; attackSlots) if(slot.unit != UnitID.init)
			{
				if(slot.hp <= 0) 
				{
					network.outgoing.send(attacker, UnitDeath(i));
					events.enque(KillUnit(attacker, slot.unit, country));
					slot = Slot.init;
				}
			}

			foreach(i, ref slot; defSlots) if(slot.unit != UnitID.init)
			{
				if(slot.hp <= 0) 
				{
					network.outgoing.send(defender, UnitDeath(i));
					events.enque(KillUnit(defender, slot.unit, country));
					slot = Slot.init;
				}
			}

			combatState = CombatState.preparing;
		}
	}
	
	override void render(Time time) 
	{
		import window.window, util.strings;
		auto renderer = app.locate!(Renderer2D);
		auto wnd = app.locate!Window;

		auto font = fonts["consola"];
		renderer.begin();
		auto title = text1024("The battle of ", state.desc.countries.find!(x => x.id == country)[0].name);
		float2 size = font.measure(title) * float2(75,75);
		float2 pos  = float2(wnd.size.x / 2 - size.x / 2, wnd.size.y - size.y);
		renderer.drawText(title, pos, float2(75, 75), font, Color.white, float2(0.35, 0.65));

		float2 nameSize = float2(50, 50);

		auto leftPlayer = state.board.players.find!(x => x.id == defender)[0];
		float2 lpos = float2(20, wnd.size.y - size.y - 50);
		renderer.drawText(leftPlayer.name, lpos, nameSize, font, leftPlayer.color);

		auto rightPlayer = state.board.players.find!(x => x.id == attacker)[0];
		auto rsize		 = font.measure(rightPlayer.name) * nameSize;
		float2 rpos		 = float2(wnd.size.x - 20 - rsize.x, wnd.size.y - size.y - 50);
		renderer.drawText(rightPlayer.name, rpos, nameSize, font, rightPlayer.color);


		drawUnits(renderer, float2(40, wnd.size.y * 0.75), font, defender, defSlots[]);
		drawUnits(renderer, float2(wnd.size.x - 90, wnd.size.y * 0.75), font, attacker, attackSlots[]);

		drawSlots(renderer, float2(wnd.size.x / 2 - 200, wnd.size.y / 2), font, defSlots);
		drawSlots(renderer, float2(wnd.size.x / 2 + 200, wnd.size.y / 2), font, attackSlots);
		renderer.end();
	}

	void drawSlots(Renderer2D* renderer, float2 center, ref Font font, Slot[] slots)
	{
		import util.strings;
		float2 start = float2(center.x, center.y + (slots.length / 2) * 100 - 25);
		foreach(i, slot; slots) if(slot.unit != UnitID.init)
		{
			auto unit = state.desc.units.find!(x => x.id == slot.unit)[0];
			auto texture = atlas[unit.texture];
					
			Color c = slot.unit == UnitID.init ? Color(0xFFeeeeee) : Color.white;
			float4 quad = float4(start.x, start.y - i * 100, start.x + 50, start.y - i * 100 + 50);
			renderer.drawQuad(quad, texture, c);

			float2 pos = float2(start.x + 75, start.y - i * 100);
			auto text  = text1024(slot.hp);
			renderer.drawText(text, pos, float2(25,25), font, Color.green);
		}
	}

	void drawUnits(Renderer2D* renderer, float2 start, ref Font font, PlayerID player, Slot[] slots)
	{
		import util.strings;
		foreach(i, unit; state.desc.units)
		{
			auto numUnits = state.board.units.count!(x => x.id       == unit.id &&
														  x.location == country &&
														  x.ruler    == player);
			numUnits -= slots.count!(x => x.unit == unit.id);

			auto texture = atlas[unit.texture];
			float4 quad = float4(start.x, start.y, start.x + 50, start.y + 50);
			renderer.drawQuad(quad, texture, Color.white);

			auto text	  = text1024(numUnits);
			auto fp		  = quad.zy + float2(10, 5);
			renderer.drawText(text, fp, float2(25,25), font, Color.green);

			start.y -= 60;
		}

	}
}

