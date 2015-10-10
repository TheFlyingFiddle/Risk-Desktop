module graphics.common;

import derelict.opengl3.gl3;
import math.vector;
import graphics.color;


import math.vector;
import std.traits;

template isAny(U, T...) {
	static if(T.length > 0) {
		static if(is(T[0] == U))
			enum isAny = true;
		else 
			enum isAny = isAny!(U, T[1 .. $]);
	} else {
		enum isAny = false;
	}
}	

template isFloatVec(T) {
	enum isFloatVec = isAny!(T, float, float2, float3, float4);
}

template isIntVec(T) {
	enum isIntVec = isAny!(T, int, int2, int3, int4);
}

template isShortVec(T) {
	static if(is(T v == Vector!(len, U), int len, U))
	{
		enum isShortVec = is(U == short);
	}
	else 
	{
		enum isShortVec = false;
	}
}

template isUintVec(T) {
	enum isUintVec = isAny!(T, uint, uint2, uint3, uint4);
}

template glUnitSize(T) {
	static if(isNumeric!T) {
		enum glUnitSize = 1;
	}
	else static if(is(T v == Vector!(len, U), int len, U)) {
		enum glUnitSize = len;
	} else static if(is(T == Color)) {
		enum glUnitSize = 4;
	} else {
		static assert(false, "Not Yet implemented");
	}
}

unittest{
	assert(glUnitSize!float3==3);
	assert(glUnitSize!uint4==4);
	assert(glUnitSize!float2==2);
}

template glNormalized(T) 
{
	static static if(isAny!(T, uint, int2, uint2, 
							int3, uint3, int4, uint4, Color)) {
								enum glNormalized = true;
							} else {
								enum glNormalized = false;
							}
}

template glType(T)
{
	static if(isFloatVec!T) {
		enum glType = GL_FLOAT;
	} else static if(isIntVec!T) {
		enum glType = GL_INT;
	} else static if(is(T == Color)) {
		enum glType = GL_UNSIGNED_BYTE;
	} else static if(isUintVec!T) {
		enum glType = GL_UNSIGNED_INT;
	} else static if(isShortVec!T) {
		enum glType = GL_SHORT;
	} else  {
		static assert(false, "Not Yet implemented");
	}
}