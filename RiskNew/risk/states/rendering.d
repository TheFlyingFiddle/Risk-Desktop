module risk.states.rendering;

import util.strings;
import util.hash;
import window.window;
import rendering.shapes,
	   rendering.combined;
import graphics.textureatlas;
import content;
import math.vector;
import graphics.color;
import risk.database;
import app.core;
import std.algorithm;

struct RenderSettings
{
	string fonts;
	string titleFont;
	string pixel;
	string unitAtlas;
	string countryAtlas;
}

struct RenderContext
{
	HashID titleFontID;
	HashID pixelID;

	//Etc.
	AtlasHandle countryAtlas;
	AtlasHandle unitAtlas;
	FontHandle  fonts;
	Renderer2D* renderer;
	Window*		wnd;

	Font titleFont()
	{
		return fonts[titleFontID];
	}

	Frame pixel()
	{
		return unitAtlas[pixelID];
	}

	this(RenderSettings settings, Application* app)
	{
		
		auto loader		 = app.locate!(AsyncContentLoader);
		this.unitAtlas	 = loader.load!TextureAtlas(settings.unitAtlas);
		this.countryAtlas = loader.load!TextureAtlas(settings.countryAtlas);
		this.fonts		 = loader.load!FontAtlas(settings.fonts);
		this.titleFontID = HashID(settings.titleFont);
		this.pixelID	 = HashID(settings.pixel);

		this.renderer  = app.locate!(Renderer2D);
		this.wnd	   = app.locate!(Window);
	}

	void drawTitle(string title)
	{
		auto font	= titleFont;
		float2 size = font.measure(title) * float2(75,75);
		float2 pos  = float2(wnd.size.x / 2 - size.x / 2, wnd.size.y - size.y);
		renderer.drawText(title, pos, float2(75, 75), font, Color.white, float2(0.35, 0.65));
	}

	void drawCountries(Board* board)
	{
		auto links	    = board.countryLinks;
		auto countries  = board.countryDescs;
		auto cInstances = board.countries;
		auto players	= board.players; 

		foreach(link; links)
		{
			auto a = countries.find!(x => x.id == link.a)[0];
			auto b = countries.find!(x => x.id == link.b)[0];
			auto p = pixel;
			(*renderer).drawSpottedLine(a.position, b.position, 2f, 5f, p, Color(0xaaaaaaaa));
		}

		foreach(cd; countries)
		{
			float2 c = cd.position;
			float2 b = cd.bounds;
			float4 quad = float4(c.x - b.x / 2, c.y - b.y / 2,
								 c.x + b.x / 2, c.y + b.y / 2);

			Color color;
			auto country = cInstances.find!(x => x.id == cd.id);
			if(country.length)
				color = players.find!(x => x.id == country[0].ruler)[0].color;
			else 
				color = Color(0xFFEEEEEE);

			(*renderer).drawQuad(quad, pixel, color);
		}
	}

	void drawUnits(Board* board)
	{
		enum x = 0.65;
		static float2[5] corners = [float2(-x, -x), float2(-x, x), float2(x, -x), float2(0, 0)];
		auto countries  = board.countryDescs;
		auto font		= titleFont;
		foreach(cd; countries)
		{
			float2 c = cd.position;
			float2 b = cd.bounds;
			foreach(i, unit; board.unitDescs)
			{
				auto texture  = unitAtlas[unit.texture];
				float2 corner = corners[i];
				float2 pos    = c - corner * (b / 2);
				float2 bounds = float2(20, 20);

				auto numUnits = board.units.count!(x => x.location == cd.id && x.id == unit.id);
				if(numUnits > 0)
				{
					float4 iconQuad = float4(pos.x - bounds.x / 2, pos.y - bounds.y / 2,
											 pos.x + bounds.x / 2, pos.y + bounds.y / 2);
					(*renderer).drawQuad(iconQuad, texture, Color.white);

					auto text	  = text1024(numUnits);
					auto size	  = font.measure(text) * float2(25, 25);
					auto fp		  = iconQuad.zy + float2(3,0);

					(*renderer).drawText(text, fp, float2(15,15), font, Color.white);

				}
			}
		}
	}
}