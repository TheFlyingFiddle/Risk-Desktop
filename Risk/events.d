module events;

import data;
import inplace;
import std.algorithm;
import log;

struct LoadBoard 
{ 
	string fileName; 
	void apply(ref RiskState state) 
	{	
		import sdl, allocation;
		logInfo("Loading Map: ", fileName);
		state.desc = fromSDLFile!(BoardDesc)(Mallocator.it, fileName);
	}
}

struct CreatePlayer 
{ 
	PlayerID id; 
	Color color; 
	string name; 
	
	void apply(ref RiskState state)
	{
		import allocation;
		//Gotta allocate since we use memory with a short lifetime here. 
		char[] data = Mallocator.it.allocate!(char[])(name.length);
		data[] = name;


		Player p;
		p.name  = cast(string)data;
		p.id    = id;
		p.color = color;
		p.money = 0;

		logInfo("Creating Player: ", p);		
		state.board.players ~= p;
	}
}

struct AssignCountry
{
	PlayerID player;
	CountryID country;
	void apply(ref RiskState state)
	{
		logInfo("Assigning Country", Country(country, player));

		auto c = state.board.countries.find!(x => x.id == country);
		if(c.length == 0)
			state.board.countries ~= Country(country, player);
		else 
			c[0].ruler = player;
	}
}

struct AssignMission
{
	PlayerID player;
	MissionID mission;

	void apply(ref RiskState state)
	{
		import log;
		logInfo(mission, " was assigned to player ", player);
		auto p = &state.board.players.find!(x => x.id == player)[0];
		p.mission = mission;
	}
}

struct GiveMoney
{
	PlayerID player;
	uint amount;

	void apply(ref RiskState state)
	{
		import log;
		logInfo(player, " was given ", amount, " money");

		auto p = &state.board.players.find!(x => x.id == player)[0];
		p.money += amount;
	}
}

struct PlaceUnit
{
	UnitID unit;
	CountryID country;
	PlayerID  player;

	void apply(ref RiskState state)
	{
		auto p   = &state.board.players.find!(x => x.id == player)[0];
		auto u   = state.desc.units.find!(x => x.id == unit)[0];
		p.money -= u.cost;
		state.board.units ~= Unit(unit, country, player);
	}
}

struct MoveUnit
{
	PlayerID player;
	UnitID unit;
	CountryID from;
	CountryID to;

	void apply(ref RiskState state)
	{
		auto u = &state.board.units.find!(x => x.location == from && x.id == unit && x.ruler == player)[0];
		u.location = to;
	}
}

struct KillUnit
{
	PlayerID player;
	UnitID unit;
	CountryID country;

	void apply(ref RiskState state)
	{
		auto idx = state.board.units.countUntil!(x => x.location == country && x.id == unit && x.ruler == player);
		state.board.units[idx] = state.board.units[$ - 1];
		state.board.units.length--;
	}
}

struct ChangeOwner
{
	CountryID country;
	PlayerID  player;

	void apply(ref RiskState state)
	{
		auto country = &state.board.countries.find!(x => x.id == country)[0];
		country.ruler = player;
	}
}