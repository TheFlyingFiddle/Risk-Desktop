module network_events;

import data;
enum InputState
{
	selectMission = 0,
	build		  = 1, 
	move		  = 2,
	combat		  = 3,
	gameOver	  = 4
}

struct EnterState
{
	InputState stateID;
}

struct CombatStarted
{
	PlayerID defender, attacker;
	CountryID country;
}

struct SendMission
{
	MissionID id;
	string descriptions;
}

struct SendMoney
{
	uint amount;
}

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
	uint slot;
}

struct UnitDeath
{
	uint   slot;
}

struct AttackUnit
{
	uint fromSlot, toSlot;
}

struct CombatResult 
{
	bool win;	
}

//A tag
struct PlayerDone { }