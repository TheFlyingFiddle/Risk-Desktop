module risk.output;

import risk.database;
enum InputState
{
	selectMission = 0,
	build		  = 1, 
	move		  = 2,
	combat		  = 3,
	gameOver	  = 4
}

struct SendEnterState
{
	InputState stateID;
}

struct SendCombatStarted
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

struct SendCombatResult
{
	bool win;
}