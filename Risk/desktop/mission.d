module desktop.mission;

import desktop.risk;
import graphics.font;
import collections;
import std.algorithm;

class MissionScreen : DesktopRiskScreen
{
	IAllocator allocator;
	HashMap!(PlayerID, List!MissionID) missions;
	this(IAllocator allocator) 
	{
		this.allocator = allocator;
		this.missions  = HashMap!(PlayerID, List!MissionID)(allocator);
	}

	override void update(Time time) 
	{
		if(missions.has(player.id) && mouse.wasPressed(MouseButton.left))
		{
			import window.window;
			auto wnd = app.locate!(Window);
			float2 start = float2(wnd.size.x - 500, wnd.size.y - 100);
			foreach(mission; missions[player.id])
			{
				auto desc = riskState.desc.missions.find!(x => x.id == mission)[0];
				auto font = fonts["consola"];
				
				float2 fsize = float2(25,25);
				float2 tsize = font.measure(desc.description) * fsize;

				Rect bounds = Rect(start, start + tsize);
				if(bounds.contains(mouse.location))
				{
					//Mission Selected. 
					acceptMission(player.id, mission);
					break;
				}
				
				start.y -= 100;
			}
		}

		while(network.outgoing.canReceive())
		{
			network.outgoing.receive(
			(PlayerID id, SendMission m) 
			{
				import log;
				logInfo("got event", m);

				if(!missions.has(id))
					missions.add(id, List!MissionID(allocator, 20));

				missions[id] ~= m.id;
			},
			(NetworkEvent e) 
			{ 
				import log;
				logInfo("....");
			});
		}
	}

	void acceptMission(PlayerID player, MissionID mission)
	{
		network.incomming.send(player, MissionAccepted(mission));
		nextTurn();
	}
	
	override void render(Time time,ref Renderer2D renderer) 
	{
		auto font   = fonts["consola"];

		import window.window;
		auto wnd = app.locate!(Window);
		float2 start = float2(wnd.size.x - 500, wnd.size.y - 100);

		if(missions.has(player.id))
		{
			foreach(mission; missions[player.id])
			{
				auto desc = riskState.desc.missions.find!(x => x.id == mission)[0];
				renderer.drawText(desc.description, start, float2(25,25), font, Color.white);
				start.y -= 100;
			}
		}

		renderer.end();
	}
}