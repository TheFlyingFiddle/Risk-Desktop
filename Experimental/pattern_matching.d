//module pattern_matching;
//
//import std.traits;
//import std.meta;
//
//enum isMatchable(T) = hasMember!(T, "peek") && is(typeof(T.peek) == T* delegate());
//struct MatchC(T...) 
//{ 
//    alias items = T;
//    alias C = CommonType!(T);
//    C value;
//    alias value this;
//
//    bool match(U)(ref U u) if(isMatchable!(U))
//    {
//        if(auto p = u.peek!C)
//        {
//            foreach(i; items)
//            {
//                if(i == *p)
//                {
//                    value = i;
//                    return true;
//                }
//            }
//        }
//        return u.peek!C;
//    }
//
//    bool match(U)(ref U u) if(!isMatchable!U)
//    {
//        foreach(i; items)
//        {	
//            if(i == u)
//            {
//                value = i;
//                return true;
//            }
//        }	
//
//        return false;
//    }
//}
//
//
//struct MatchR(T...) if(T.length == 2 && isExpressions!T && isIntegral!(CommonType!T))
//{
//    alias min   = T[0];
//    alias max   = T[1];
//    alias C     = CommonType!(T);
//
//    bool match(U)(ref U u) if(isMatchable!(U))
//    {
//        if(auto p = u.peek!C)
//        {
//            if(T[0] >= *p && T[1] < *p)
//            {
//                value = i;
//                return true;
//            }
//
//        }
//        return false;
//    }
//
//    bool match(U)(ref U u) if(!isMatchable!U)
//    {
//        if(T[0] >= *p && T[1] < *p)
//        {
//            value = i;
//            return true;
//        }
//
//        return false;
//    }
//}
//
//struct MatchP(alias pred) 
//{ 
//    alias func = pred;
//}
//
//template isInstantiationOf(alias T)
//{
//    template helper(alias func)
//    {
//        alias P = Parameters!func;
//        enum helper = isInstanceOf!(T, P[0]);
//    }
//    alias isInstantiationOf = helper;
//}
//
//
//template isNonMatchType(alias T)
//{
//    alias P = Parameters!(T)[0];
//
//    enum isNonMatchType = !isInstanceOf!(MatchC, P) &&
//                          !isInstanceOf!(MatchR, P) &&
//                          !isInstanceOf!(MatchP, P);
//}
//
//template ctypes_to_consts(alias func)
//{
//    alias P = Parameters!func;
//    alias ctypes_to_consts = AliasSeq!(P[0].items);
//}
//
//template match(Handlers...) if(allSatisfy!(isCallable, Handlers))
//{
//    alias constants = Filter!(isInstantiationOf!MatchC, Handlers);
//    alias ranges    = Filter!(isInstantiationOf!MatchR, Handlers);
//    alias types		= Filter!(isNonMatchType,			Handlers);
//
//    void check_errors()
//    {
//        foreach(i, c0; constants)
//        {
//            alias P0 = Parameters!(c0)[0];
//            foreach(c1; constants[i + 1 .. $])
//            {
//                alias P1 = Parameters!(c1)[0];
//                foreach(item0; P0.items)
//                {
//                    foreach(item1; P1.items)
//                    {
//                        static if(item0 == item1)
//                        {
//                            enum error = "Constant: " ~ item0.stringof ~ " is in use by two diffrent " ~
//                                "patterns " ~ P0.stringof ~ " and " ~ P1.stringof; ~ ".";
//                            static assert(false, error);
//                        }
//                    }
//                }
//            }
//
//            foreach(r; ranges)
//            {
//                alias PR = Parameters!(r)[0];
//                foreach(item; P0.items)
//                {
//                    if(item >= PR.min && item <= PR.max)
//                    {
//                        enum error = "Constant: " ~ item.stringof ~ " is in use by two diffrent " ~
//                             "patterns " ~ P0.stringof ~ " and " ~ PR.stringof ~ ".";
//                        static assert(false, error);
//                    }
//                }
//            }
//        }
//
//        foreach(i, r0; ranges)
//        {
//            alias PR0 = Parameters!(r0)[0];
//            foreach(r1; ranges[i .. $])
//            {
//                alias PR1 = Parameters!(r1)[0];
//                static if(PR0.min < PR1.max && PR1.min < PR0.max)
//                {
//                    enum error = "Range patterns overlap " ~ 
//                        PR0.stringof ~ " : " ~ PR1.stringof ~ ".";
//                    static assert(false, error);
//                }
//            }
//        }
//
//
//    }
//
//
//    auto ref match(T)(T t)
//    { 
//        foreach(c; constants)
//        {
//            alias P = Parameters!c;
//            alias Cont = P[0];
//
//            Cont cont = void;
//            if(cont.match!(T)(t))
//                return c(cont);
//        }
//
//        foreach(r; ranges)
//        {
//            alias P = Parameters!r;
//            alias Cont = P[0];
//
//            Cont cont = void;
//            if(cont.match!(T)(t))
//                return r(cont);
//        }
//
//        foreach(ft; types)
//        {
//            alias P = Parameters!ft;
//            alias type = P[0];
//
//            type typ = void;
//            if(matchType(t, typ))
//                return ft(typ);
//        }
//
//        //It should never ever get here. 
//        assert(false, "Case fallthrough!");
//    }
//}
//
//
//bool matchType(T, U)(ref T t, ref U value) if(isMatchable!T)
//{
//    if(auto p = t.peek!U)
//    {
//        value = *p;
//        return true;
//    }
//    return false;
//}
//
//bool matchType(T, U)(ref T t, ref U u) if(!isMatchable!T)
//{
//    static assert(is(T : U), "...");
//    u = t;
//    return true;
//}
//
//unittest
//{
//    import std.stdio;
//    foreach(i; 0 .. 10)
//    {
//        i.match!((M!(1, 2, 3) n) =>  "one two or three",
//                 (M!(3, 4, 5) n) =>  "four or five",
//                 (int n) => "Default value").writeln;
//    }
//
//    readln;
//}
//
//class A { }
//pragma(msg, __traits(classInstanceSize, A));