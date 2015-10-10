module graphics.frame;

import math.vector;
import graphics.texture;

struct Frame
{
	Texture2D texture;
	float4 coords;

	this(Texture2D texture)
	{
		this.texture = texture;
		this.coords = float4(0,0,1,1);
	}

	this(Texture2D texture, short4 srcRect)
	{
		this.texture = texture;
		this.coords = float4(srcRect.x / cast(float)texture.width,
							 srcRect.y / cast(float)texture.height,
							 (srcRect.x + srcRect.z) / cast(float)texture.width,
							 (srcRect.y + srcRect.w) / cast(float)texture.height);
	}

	this(Texture2D texture, float4 srcRect)
	{
		this.texture = texture;
		this.coords = float4(srcRect.x / texture.width,
							 srcRect.y / texture.height,
							 (srcRect.x + srcRect.z) / texture.width,
							 (srcRect.y + srcRect.w) / texture.height);
	}
}