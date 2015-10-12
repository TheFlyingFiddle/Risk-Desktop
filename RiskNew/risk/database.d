module risk.database;
public import math.vector;
public import graphics.color;
public import collections.list;
import util.hash;
import sdl;

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

private struct SDLBoard
{
	//Immutable data: 
	ContinentDesc[] continents;
	CountryDesc[]	countries;
	CountryLink[]	links;
	UnitDesc[]		units;
	MissionDesc[]	missions;

	Player[]	players;
	Country[]	countryInstances;
	Unit[]		unitInstances; 
}

//Sorta mutable data
struct Board
{
	//Immutable data: 
	ContinentDesc[] continentDescs;
	CountryDesc[]	countryDescs;
	CountryLink[]	countryLinks;
	UnitDesc[]		unitDescs;
	MissionDesc[]	missionDescs;

	//Semi-mutable data
	GrowingList!(Player)	players;
	GrowingList!(Unit)		units; 
	List!(Country)			countries;

	import allocation;
	static Board load(A)(ref A allocator, string file)
	{
		auto sdl_board = fromSDLFile!SDLBoard(allocator, file);
		Board b;

		b.continentDescs = sdl_board.continents;
		b.countryDescs   = sdl_board.countries;
		b.countryLinks   = sdl_board.links;
		b.missionDescs   = sdl_board.missions;
		b.unitDescs		 = sdl_board.units;

		b.players		 = GrowingList!(Player)(allocator, 10);
		b.units			 = GrowingList!(Unit)(allocator, 1024);
		b.countries		 = List!(Country)(allocator, b.countryDescs.length);

		b.players	    ~= sdl_board.players;
		b.units		    ~= sdl_board.unitInstances;
		b.countries		~= sdl_board.countryInstances;
		
		return b;
	}

	void save(string file)
	{	
		SDLBoard b;
		b.continents = continentDescs;
		b.countries   = countryDescs;
		b.links   = countryLinks;
		b.missions   = missionDescs;
		b.units		 = unitDescs;
		b.players			= cast(Player[])players.array;
		b.unitInstances		= cast(Unit[])units.array;
		b.countryInstances	= cast(Country[])countries.array;
		toSDLFile!SDLBoard(b, file);
	}
}