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

#include "EdgeDetectShare.hlsl"

#include "SAAShared.hlsl"


//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------

Texture2D ColorBuffer             : register( t0 );  // The input color buffer to post-process
RWByteAddressBuffer EdgeHBitArray : register( u0 );  // Stores presence/absence of horizontal edge, 1 bit/pixel
RWByteAddressBuffer EdgeVBitArray : register( u1 );  // Stores presence/absence of vertical edge, 1 bit/pixel


//-----------------------------------------------------------------------------------------------------
// We are processing the color buffer in tiles of (32x32) pixels.
// Each thread processes a column of 32 pixels.
// Each thread group has 32 such threads, so corresponds to the processing of a tile.
// Therefore the thread-related system values are automatically assigned thus:
// SV_GroupID = tile coordinates (e.g. (3,2,0) = 3rd tile from the left, 2nd tile from top)
// SV_DispatchThreadID = coordinates of the column of 32 pixels of the color buffer we are processing
// (X direction: in pixels; Y direction: in tiles)
// SV_GroupThreadID = which column in tile we are processing (e.g. (27,0,0) = tile's 28th column).
//-----------------------------------------------------------------------------------------------------


[numthreads(32, 1, 1)]	// Each thread group is a grid of (32, 1, 1) = 32 threads
void CSMain( uint3 TileCoords      : SV_GroupID,
             uint3 ColumnCoords    : SV_DispatchThreadID,
			 uint3 TileColumnIndex : SV_GroupThreadID
           )
{    
	
	// ColumnCoords.y is in tiles, so need to multiply by 32 to get proper coords for Load
	uint2  PixelCoords = uint2(ColumnCoords.x, ColumnCoords.y << 5);
	float4 Pixel       = ColorBuffer.Load( float3(PixelCoords, 0) );
	
	uint EdgeVFlag = 0;

	[unroll] for( int i = 0; i < 32; i++ ) 
	{
		// Load bottom neighbor and right neighbor
		float4 Bottom = ColorBuffer.Load( uint3(PixelCoords.x    , PixelCoords.y + 1, 0) );
		float4 Right  = ColorBuffer.Load( uint3(PixelCoords.x + 1, PixelCoords.y    , 0) );

        bool edgeBottom = EdgeDetectColor( Pixel, Bottom );
        bool edgeRight  = EdgeDetectColor( Pixel, Right );

		if( edgeBottom )
		{	// We have an horizontal edge so update the horizontal edge buffer now.
			EdgeHBitArray.InterlockedAdd(
			    (TileCoords.x + ((ColumnCoords.y << 5) + i) * ColorBufferTileCount.x) << 2,
			    1 << (31 - TileColumnIndex.x));
		}
		if( edgeRight )
		{	// We have a vertical edge
			EdgeVFlag += 1 << (31 - i);
		}
		Pixel = Bottom;
		PixelCoords.y++;
	}
	EdgeVBitArray.Store(
	    (TileCoords.y + ColumnCoords.x * ColorBufferTileCount.y) << 2, 
		EdgeVFlag);
}
