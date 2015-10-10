module desktop.move;

import desktop.risk;
import graphics.font;
import collections;
import std.algorithm;

class DesktopMoveScreen : DesktopRiskScreen
{
	uint from, to;
	this() { }
	override void load(ref AsyncContentLoader loader) 
	{
		from = to = uint.max;
	}

	override void update(Time time) 
	{
		import window.window;
		auto wnd = app.locate!(Window);
		auto desc = riskState.desc;

		if(mouse.wasPressed(MouseButton.left))
		{
			Rect doneBtn = Rect(25, 25, 100, 50);
			if(doneBtn.contains(mouse.location))
			{
				network.incomming.send(player.id, PlayerDone());
				nextTurn();
				from = to = uint.max;
				return;
			}

			if(from != uint.max && to != uint.max)
			{
				float2 start = float2(40, wnd.size.y * 0.75);
				bool newSelected = false;
				foreach(i, unit; desc.units)
				{
					Rect bounds = Rect(start, start + float2(50,50));
					if(bounds.contains(mouse.location))
					{
						auto count = riskState.board.units.count!(x => x.id		  == unit.id && 
																	   x.location == desc.countries[from].id &&
																       x.ruler    == player.id);
						if(count > 0)
							moveUnit(unit.id);
						break;
					}
					start.y -= 60;
				}
			}

			foreach(i, country; desc.countries)
			{
				Rect bounds = Rect(country.position - country.bounds / 2, country.position + country.bounds / 2);
				if(bounds.contains(mouse.location))
				{
					auto e = riskState.board.countries.find!(x => x.id == country.id)[0];
					if(e.ruler == player.id && from == uint.max)
					{
						from = i; 
					} 
					else if(from != uint.max && from != i)
					{
						auto fc	  = desc.countries[from];
						auto link = desc.links.find!(x => 
										(x.a == country.id || x.b == country.id) &&
										(x.a == fc.id || x.b == fc.id));
						if(link.length)
						{
							to = i;
						}
					}
				}
			}
		}
	}

	void moveUnit(UnitID unit)
	{
		auto countries = riskState.desc.countries;
		network.incomming.send(player.id, UnitMoved(unit, countries[from].id, countries[to].id));
	}

	override void render(Time time,ref Renderer2D renderer) 
	{
		import window.window, util.strings;
		auto wnd = app.locate!(Window);

		auto frame = atlas["pixel"];
		auto font  = fonts["consola"];
		auto countries   = riskState.desc.countries;

		if(from != uint.max)
		{
			auto country = countries[from];
			float2 cp    = country.position;
			float2 cb	 = country.bounds;

			float4 bounds = float4(cp.x - cb.x / 2, cp.y - cb.y / 2,
								   cp.x + cb.x / 2, cp.y + cb.y / 2);

			renderer.drawQuadOutline(bounds, 2, frame, Color.white);
		}

		if(to != uint.max)
		{
			auto country = countries[to];
			float2 cp    = country.position;
			float2 cb	 = country.bounds;

			float4 bounds = float4(cp.x - cb.x / 2, cp.y - cb.y / 2,
								   cp.x + cb.x / 2, cp.y + cb.y / 2);

			renderer.drawQuadOutline(bounds, 2, frame, Color.white);

			//Movement line
			renderer.drawLine(cp, countries[from].position, 2, frame, Color(0xaaee00ee));

			float2 start = float2(40, wnd.size.y * 0.75);

			foreach(i, unit; riskState.desc.units)
			{
				auto texture = atlas[unit.texture];
				auto c		  = riskState.board.countries.find!(x => x.id == countries[from].id)[0];
				auto numUnits = riskState.board.units.count!(x => x.location == countries[from].id && 
																  x.id == unit.id &&
																  x.ruler == c.ruler);

				float4 quad = float4(start.x, start.y, start.x + 50, start.y + 50);
				renderer.drawQuad(quad, texture, Color.white);

				auto text	  = text1024(numUnits);
				auto size	  = font.measure(text) * float2(25, 25);
				auto fp		  = (quad.xy + quad.zw) / 2 - size / 2;
				renderer.drawText(text, fp, float2(25,25), font, Color.black);

				start.y -= 60;
			}

		}


		float4 doneBtn = float4(25, 25, 125, 75);
		renderer.drawQuad(doneBtn, frame, Color(0xFF999999));
		renderer.drawText("Done!", doneBtn.xy, float2(25, 25), font, Color.white);
	}
}