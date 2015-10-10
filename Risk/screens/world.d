module screens.world;

import screens.risk_screen;
import std.algorithm;

class WorldScreen : RiskScreen
{
	AtlasHandle atlas;
	this() { super(false, false); }

	override void load(ref AsyncContentLoader loader)
	{
		atlas = loader.load!TextureAtlas("Atlas");
	}


	override void render(Time time, ref Renderer2D renderer)
	{
		enum x = 0.65;
		static float2[5] corners = [float2(-x, -x), float2(-x, x), float2(x, -x), float2(0, 0)];

		import util.strings;

		renderer.begin();

		auto desc  = riskState.desc;
		auto board = riskState.board;

		auto font  = fonts["consola"];
		auto pixel = atlas["pixel"];


		foreach(link; desc.links)
		{
			auto a = desc.countries.find!(x => x.id == link.a)[0];
			auto b = desc.countries.find!(x => x.id == link.b)[0];
			renderer.drawSpottedLine(a.position, b.position, 2, 5, pixel, Color(0xaaaaaaaa));
		}

		foreach(cd; desc.countries)
		{
			float2 c = cd.position;
			float2 b = cd.bounds;
			float4 quad = float4(c.x - b.x / 2, c.y - b.y / 2,
								 c.x + b.x / 2, c.y + b.y / 2);

			Color color;
			auto country = board.countries.find!(x => x.id == cd.id);
			if(country.length)
				color = board.players.find!(x => x.id == country[0].ruler)[0].color;
			else 
				color = Color(0xFFEEEEEE);

			renderer.drawQuad(quad, pixel, color);

			foreach(i, unit; desc.units)
			{
				auto texture  = atlas[unit.texture];
				float2 corner = corners[i];
				float2 pos    = c - corner * (b / 2);
				float2 bounds = float2(20, 20);

				auto numUnits = board.units.count!(x => x.location == cd.id && x.id == unit.id);
				if(numUnits > 0)
				{
					float4 iconQuad = float4(pos.x - bounds.x / 2, pos.y - bounds.y / 2,
											 pos.x + bounds.x / 2, pos.y + bounds.y / 2);
					renderer.drawQuad(iconQuad, texture, Color.white);

					auto text	  = text1024(numUnits);
					auto size	  = font.measure(text) * float2(25, 25);
					auto fp		  = iconQuad.zy + float2(3,0);
					renderer.drawText(text, fp, float2(15,15), font, Color.white);

				}
				
			}
		}

		renderer.end();
	}
}