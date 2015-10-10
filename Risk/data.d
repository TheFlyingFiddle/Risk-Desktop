module data;

public import math.vector;
public import graphics.texture;
public import graphics.color;
import util.hash;
import sdl : Convert;

HashID stringToHash(string s)
{
	return HashID(s);
}

CountryID[] uintsToCountries(uint[] ints)
{
	CountryID[] c;
	foreach(i; ints)
		c ~= CountryID(i);
	return c;
}

struct CountryID 
{ 
	uint id; 

	static CountryID fromSDL(uint id)
	{
		return CountryID(id);
	}

	uint toSDL()
	{
		return id;
	}
} 

struct PlayerID  
{ 
	uint id; 
	static PlayerID fromSDL(uint id)
	{
		return PlayerID(id);
	}

	uint toSDL()
	{
		return id;
	}
}

struct UnitID    
{ 
	uint id;
	static UnitID fromSDL(uint id)
	{
		return UnitID(id);
	}

	uint toSDL()
	{
		return id;
	}
} 

struct MissionID 
{ 
	uint id; 
	static MissionID fromSDL(uint id)
	{
		return MissionID(id);
	}

	uint toSDL()
	{
		return id;
	}
} 

struct CountryDesc
{
	string name;
	@Convert!(stringToHash) HashID texture;
	CountryID id;

	float2 position;
	float2 bounds; 
}

struct CountryLink
{
	CountryID a, b;
}

struct UnitDesc
{
	UnitID id;
	uint hp; 
	uint attack;
	uint cost;
	@Convert!(stringToHash) HashID texture;
}

struct MissionDesc
{
	MissionID id; 
	string description;
	string winningCondition;
}

struct ContinentDesc
{
	string name;
	@Convert!(uintsToCountries) CountryID[] countries;
	uint   bonus;
}

struct Player
{	
	string				 name;
	PlayerID			 id;
	MissionID			 mission;
	Color				 color;
	uint				 money;
}

struct Country
{
	CountryID			id;
	PlayerID			ruler;
}

struct Unit
{
	UnitID id;
	CountryID location; 
	PlayerID  ruler;
}

//Immmutable data
struct BoardDesc
{
	ContinentDesc[] continents;
	CountryDesc[]	countries;
	CountryLink[]	links;
	UnitDesc[]		units;
	MissionDesc[]   missions;
}

//Sorta mutable data
struct Board
{
	Player[]	players;
	Country[]	countries;
	Unit[]		units; 
}

struct RiskState
{
	BoardDesc desc;
	Board	  board;
}