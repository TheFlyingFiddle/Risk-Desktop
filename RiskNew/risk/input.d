module risk.input;

import risk.database;

struct MissionAccepted
{
	MissionID id;
}

struct UnitPlaced
{
	CountryID country;
	UnitID	  unit;
}

struct UnitMoved
{
	UnitID unit;
	CountryID from, to;
}

struct PositionUnit
{
	UnitID unit;
	uint   slot;
}

struct UnitDeath
{
	uint slot;
}

struct AttackUnit
{
	uint fromSlot, toSlot;
}

struct CombatResult
{
	bool win;
}

//A tag used by various state logic.
struct PlayerDone { }