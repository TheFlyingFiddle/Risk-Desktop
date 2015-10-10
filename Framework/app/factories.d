module app.factories;


import app.core;
import app.components;
import app.screen;

import graphics.color;
import content;
import window.window;
import concurency.task;
import allocation;
import rendering;
import sound;

struct DesktopAppConfig
{
	size_t numServices, numComponents;
	string name; 
	WindowConfig windowConfig;
	ConcurencyConfig concurencyConfig;
	ContentConfig contentConfig;
	RenderConfig renderConfig;
	SoundConfig  soundConfig;
}


Application* createDesktopApp(A)(ref A al, DesktopAppConfig config)
{
	Application* app = al.allocate!Application(al, config.numServices, config.numComponents, config.name);

	//Only load items through the loader please! :)
	auto loader	     = al.allocate!AsyncContentLoader(al, config.contentConfig);
	app.addService(loader);

	auto window		= al.allocate!WindowComponent(config.windowConfig);
	auto task		= al.allocate!TaskComponent(al, config.concurencyConfig);
	auto screen		= al.allocate!ScreenComponent(al, 20);
	auto sound		= al.allocate!SoundComponent(al, config.soundConfig);


	auto render     = al.allocate!RenderComponent(al, config.renderConfig);
	app.addComponent(window);
	app.addComponent(task);
	app.addComponent(screen);
	app.addComponent(render);
	app.addComponent(sound);

	return app;
}