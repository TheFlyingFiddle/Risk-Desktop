module content.reloading;
import concurency.task;
import content.content;
import std.socket;
import allocation;

version(RELOADING)
{
	void setupReloader(uint ip, ushort port, AsyncContentLoader* loader)
	{
		doPoolTask!reloading(ip, port, loader);
	}

	private void connect(TcpSocket socket, uint ip, ushort port)
	{
		import std.stdio;
		auto remote = new InternetAddress(ip, port);
		socket.connect(remote);

		socket.blocking = true;
	}

	void reloading(uint ip, ushort port, AsyncContentLoader* loader)
	{
		registerThread("reloader");
		auto socket  = new TcpSocket();
		connect(socket, ip, port);

		import log;
		logInfo("Listening on port ", port);
		ubyte[1024 * 8] buffer; ubyte[] buf = buffer[];
		while(true) // <- Gotta fix this!
		{	
			import util.bitmanip;

			waitForData(2, socket, buffer[]);
			auto numItems = buf.read!ushort; buf = buffer[];
			import log : logInfo;
			logInfo("Received: ", numItems, " items!");


			foreach(i; 0 .. numItems)
			{
				waitForData(2, socket, buffer[]);
				auto strLen = buf.read!ushort; buf = buffer[];
				waitForData(strLen, socket, buffer[]);
				auto name   = cast(string)buffer[0 .. strLen - 1];
				performReload(name, loader);
				
				//Ignore the actual data.
				waitForData(4, socket, buffer[]);
				auto itemLen = buf.read!uint; buf = buffer[];
				while(itemLen)
				{
					import std.algorithm;
					auto d = min(itemLen, buffer[].length);
					itemLen -= d;
					waitForData(d, socket, buffer[]);
				}
			}
			
			
			//
			//import util.bitmanip;
			//auto buf = buffer[0 .. received];
			//auto numItems = buf.read!ushort;
			//received	= cast(uint)socket.receive(buffer[0 .. 2]); 
			//
			//logInfo("received ", numItems, " items");
			//
			//foreach(i; 0 .. numItems)
			//{
			//    received = cast(uint)socket.receive(buffer);
			//    auto name   = buffer.read!string;
			//    auto length = buffer.read!uint;
			//}
			//

			//auto array = Mallocator.it.allocate!(char[])(i);
			//array[0 .. i] = cast(char[])buffer[0 .. i];
			//doTaskOnMain!performReload(cast(string)array, loader);
		}
	}

	void waitForData(size_t dataSize, Socket socket, ubyte[] buffer)
	{
		int read = 0;
		while(read < dataSize)
		{
			auto r = socket.receive(buffer[read .. dataSize]);
			if(r == Socket.ERROR)
			{
				enforce(wouldHaveBlocked(), "Failed to read from socket!");
				continue;
			}

			read += r;
		}
	}

	void performReload(string id, AsyncContentLoader* loader)
	{
		import log;
		logInfo("Attempting to reload: ", id);

		import std.path, std.conv, util.hash;
		auto path = id[0 .. $ - id.extension.length];
		loader.reload(HashID(path.to!uint));
		Mallocator.it.deallocate(cast(void[])id);
	}
}