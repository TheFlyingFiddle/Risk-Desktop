import std.stdio;

import concurency.task;
import external_libraries;
import sdl;
import log;
import app.factories;
import allocation;
import app.screen;

int main(string[] argv)
{
	import core.memory;
	GC.disable();
	initializeScratchSpace(1024 * 1024);

	init_dlls();
	scope(exit) shutdown_dlls();

	try
	{
		auto config = fromSDLFile!(DesktopAppConfig)(Mallocator.it, "config.sdl");
		run(config);
	}
	catch(Throwable t)
	{		
		logErr("Crash!\n", t);
		while(t.next)
		{
			t = t.next;
			logErr(t);
		}

		import std.stdio;
		readln;
	}

    return 0;
}

void run(DesktopAppConfig config)
{
	auto region = RegionAllocator(Mallocator.it.allocateRaw(1024 * 1024 * 10, 64));
	auto stack  = ScopeStack(region);
	auto cstack = stack.allocate!(CAllocator!(ScopeStack))(stack);
	auto application = createDesktopApp(stack, config);
	//application.addComponent(new RiskComponent(stack));
	//application.addComponent(new DesktopNetworkComponent(stack));

	import graphics;
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	import std.datetime;
	import core.time;
	application.run(TimeStep.fixed, 33.msecs);
}
