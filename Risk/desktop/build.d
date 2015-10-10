module desktop.build;

import desktop.risk;
import graphics.font;
import collections;
import std.algorithm;

class DesktopBuildScreen : DesktopRiskScreen
{
	uint selectedUnit;

	this() { }

	override void load(ref AsyncContentLoader loader) 
	{
		selectedUnit = uint.max;
	}
	

	override void update(Time time) 
	{
		import window.window;
		auto wnd = app.locate!(Window);

		if(mouse.wasPressed(MouseButton.left))
		{
			float2 start = float2(40, wnd.size.y * 0.75);
			bool newSelected = false;
			foreach(i, unit; riskState.desc.units)
			{
				Rect bounds = Rect(start, start + float2(50,50));
				if(bounds.contains(mouse.location))
				{
					if(selectedUnit != i) newSelected = true;
					selectedUnit = i;
					break;
				}
				start.y -= 60;
			}

			if(!newSelected && selectedUnit != uint.max) 
			{
				foreach(country; riskState.desc.countries)
				{
					Rect cbounds = Rect(country.position - country.bounds / 2, country.position + country.bounds / 2);
					if(cbounds.contains(mouse.location))
					{
						auto e = riskState.board.countries.find!(x => x.id == country.id)[0];
						if(e.ruler == player.id)
						{
							placeUnit(e.id, riskState.desc.units[selectedUnit].id);
							break;
						}
					}
				}
			}
		}

		if(player.money == 0)
		{
			selectedUnit = uint.max;
			network.incomming.send(player.id, PlayerDone());
			nextTurn();
		} 
		else if(selectedUnit != uint.max)
		{
			auto unit = riskState.desc.units[selectedUnit];
			if(unit.cost > player.money)
				selectedUnit = uint.max;
		}
	}

	void placeUnit(CountryID country, UnitID unit)
	{
		network.incomming.send(player.id, UnitPlaced(country, unit));
	}

	override void render(Time time,ref Renderer2D renderer) 
	{
		import window.window, util.strings;
		auto wnd = app.locate!(Window);

		float2 start = float2(40, wnd.size.y * 0.75);
		auto font = fonts["consola"];
		foreach(i, unit; riskState.desc.units)
		{
			auto texture = atlas[unit.texture];
			float4 quad = float4(start.x, start.y, start.x + 50, start.y + 50);
			Color c		= player.money >= unit.cost ? Color.white : Color(0xFFaaaaaa); 
			renderer.drawQuad(quad, texture, selectedUnit == i ? Color.green : c);

			auto text	  = text1024(unit.cost);
			auto size	  = font.measure(text) * float2(25, 25);
			auto fp		  = (quad.xy + quad.zw) / 2 - size / 2;
			renderer.drawText(text, fp, float2(25,25), font, Color.black);

			start.y -= 60;
		}

		import util.strings;
		auto text = text1024("Currency: ", player.money);
		renderer.drawText(text, float2(10, 10), float2(25,25), font,  Color.white); 
	}
}