//module socket;
//
//import std.socket;
//import allocation;
//
//struct TCPSocket
//{
//    private TcpSocket socket;
//    private InternetAddress remote;
//    
//    bool connect(uint ip, ushort port)
//    {
//        assert(address is null);
//        address = new InternetAddres(ip, port);
//        socket.connect(address);
//    }
//
//    bool isConnected()
//    {
//        return socket.isAlive();
//    }
//
//    size_t send(void[] data)
//    {
//        return socket.send(data, SocketFlags.NONE);
//    }
//
//    size_t receive(void[] data)
//    {
//        return socket.recive(data, SocketFlags.NONE);
//    }	
//}
//
//struct TcpServer
//{
//    private TcpSocket socket;
//    private InternetAddress local;
//    this(ushort port) { } //Dostuff etc. 
//}
//
//struct UDPSocket
//{
//    private UdpSocket socket;
//    private InternetAddress local;
//
//    //Do stuff. 
//}
//
////Socket with built in reliability. 
////Window sizes etc. 
////Future project should be fun. 
//struct ReliableUdpSocket {	}
//
//struct FiberTcpSocket 
//{
//    import core.thread;
//
//    private TCPSocket socket;
//    void connect(uint ip, ushort port)
//    {
//        connect(ip, port);
//        while(!socket.isAlive)
//        {
//            Fiber.yield();
//        }
//    }
//
//    size_t send(void[] data)
//    {
//        size_t sent = 0;
//        while(true)
//        {
//            sent += socket.send(data[sent .. $]);
//            if(sent < data.length)
//                Fiber.yeild();
//            else
//                break;
//        }
//
//        return sent;
//    }
//
//    size_t receive(void[] data, bool reciveAll = false)
//    {
//        size_t received = 0;
//        while(true)
//        {
//            received += socket.receive(data[received .. $]);
//            if(receiveAll && received < data.length)
//                Fiber.yeild();
//            else
//                break;
//        }
//        
//        return received;		
//    }
//
//    //Could use a serializer here. 
//    T read(T)()
//    {
//        T t = void;
//        void[T.sizeof] data = void;
//        receive(data, true);
//        return *cast(T*)data.ptr;
//    }
//
//    //Could use a serializer here. 
//    void send(T)(auto ref T t)
//    {
//        send(cast(void[])(&t[0 .. 1]));
//    }
//}