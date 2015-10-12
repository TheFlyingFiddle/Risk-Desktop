module risk.database_operations;

import risk.database;
import std.algorithm;
import log;

//These must forward into network output functions somehow. 
void assignCountry(Board* board, PlayerID player, CountryID country)
{
	logInfo("Assigning Country", Country(country, player));

	auto c = board.countries.find!(x => x.id == country);
	if(c.length == 0)
		board.countries ~= Country(country, player);
	else 
		c[0].ruler = player;
}

void assignMission(Board* board, PlayerID player, MissionID mission)
{
	board.players.find!(x => x.id == player)[0].mission = mission;
}