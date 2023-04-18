// Copyright 2012 Intel Corporation
// All Rights Reserved
//
// Permission is granted to use, copy, distribute and prepare derivative works of this
// software for any purpose and without fee, provided, that the above copyright notice
// and this statement appear in all copies. Intel makes no representations about the
// suitability of this software for any purpose. THIS SOFTWARE IS PROVIDED "AS IS."
// INTEL SPECIFICALLY DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, AND ALL LIABILITY,
// INCLUDING CONSEQUENTIAL AND OTHER INDIRECT DAMAGES, FOR THE USE OF THIS SOFTWARE,
// INCLUDING LIABILITY FOR INFRINGEMENT OF ANY PROPRIETARY RIGHTS, AND INCLUDING THE
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Intel does not
// assume any responsibility for any errors which may appear in this software nor any
// responsibility to update it.

#include "SAAShared.hlsl"

//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------

ByteAddressBuffer EdgeHBitArray : register( t0 );
ByteAddressBuffer EdgeVBitArray : register( t1 );
RWTexture2D<float4> Result      : register( u0 );


[numthreads(1, 1, 1)]
void CSMain( uint3 Coords : SV_GroupID)
{
	float4 Color = float4(0.f, 0.f, 0.f, 0.f);

	uint HFlags = EdgeHBitArray.Load( ( (Coords.x >> 5) + (Coords.y * ColorBufferTileCount.x) ) << 2);
	uint VFlags = EdgeVBitArray.Load( ( (Coords.y >> 5) + (Coords.x * ColorBufferTileCount.y) ) << 2);
	
	uint PixelHFlag = (HFlags >> (31 - (Coords.x % 32))) & 1;
	uint PixelVFlag = (VFlags >> (31 - (Coords.y % 32))) & 1;

	if(PixelHFlag | PixelVFlag != 0)
	{
		Color.r = (float) (PixelHFlag & PixelVFlag);
		Color.g = (float) (PixelHFlag & !PixelVFlag);
		Color.b = (float) (PixelVFlag & !PixelHFlag);
		Result[Coords.xy] = Color;
	}
}
