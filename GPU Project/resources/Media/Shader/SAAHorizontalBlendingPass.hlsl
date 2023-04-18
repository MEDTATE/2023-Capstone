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

//-----------------------------------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------------------------------

ByteAddressBuffer EdgeHBitArray : register( t0 );  // Stores presence/absence of horizontal edge, 1 bit/pixel
Texture2D ColorBuffer           : register( t1 );  // The input color buffer to post-process
RWTexture2D<float4> Result      : register( u0 );  // the output color buffer

SamplerState LinearSampler : register( s0 );


//-----------------------------------------------------------------------------------------------------
// Tweakables
//-----------------------------------------------------------------------------------------------------
#define yinter 0.5f                 // y intercept
#define MinimumEdgeLength    2      // If an edge's length is less than this, don't blend


//-----------------------------------------------------------------------------------------------------
// We are processing the color buffer in tiles of (32x32) pixels.
// Each thread processes a horizontal group of 32 pixels.
// Each thread group has 32 such threads, so corresponds to the processing of a tile.
// Therefore the thread-related system values are automatically assigned thus:
// SV_GroupID = tile coordinates (e.g. (3,2,0) = 3rd tile from the left, 2nd tile from top)
// SV_DispatchThreadID = coordinates of the 32 pixels group of the color buffer we are processing
// (X direction: in tiles; Y direction: in pixels)
// SV_GroupThreadID = which row in tile we are processing (e.g. (0,27,0) = tile's 28th row).
//-----------------------------------------------------------------------------------------------------

[numthreads(1,32,1)]
void CSMain( uint3 TileCoords      : SV_GroupID,
             uint3 RowCoords       : SV_DispatchThreadID)
{
	// This is the offset (in 32-bit = 4 bytes units) where the edge flags are stored in EdgeHBitArray for this row (32 pixels group)
	uint FlagsOffset     = RowCoords.x + RowCoords.y * ColorBufferTileCount.x;
	// Same for the row above...
	uint FlagsUpOffset   = FlagsOffset - ColorBufferTileCount.x;
	// And the row below.
	uint FlagsDownOffset = FlagsOffset + ColorBufferTileCount.x;
	
	// We retrieve the edge flags for this row of 32 pixels, as well as the rows on the left and right
	// (The << 2 converts the offset to byte units)
	uint3 current = EdgeHBitArray.Load3( (FlagsOffset - 1) << 2);
	uint BgMask = current.y;	// This is the edge bit mask for this row (Bg stands for "blending group")


	if(BgMask != 0)
	{	// There is at least one horizontal discontinuity flagged in this group of 32 pixels...
		uint3 downLine = EdgeHBitArray.Load3( (FlagsDownOffset - 1) << 2 );
		uint3 upLine   = EdgeHBitArray.Load3( (FlagsUpOffset -  1)  << 2 );
		
		uint left = current.x, right = current.z;
		uint downLeft = downLine.x, down = downLine.y, downRight = downLine.z;
		uint upLeft = upLine.x, up = upLine.y, upRight = upLine.z;

		uint BgMaskU = BgMask;// & (~up);
		uint BgMaskD = BgMask;// & (~down);

		while(BgMaskU != 0)
		{	// We are scanning for discontinuities left to right.
			// First we look for the highest set bit in the mask, which corresponds to the leftmost pixel in the group with a horizontal discontinuity.
			uint from = firstbithigh( BgMaskU );
			uint NewMask = 0, LeftBitsCount = 0;

			if(from == 31)
			{	// The leftmost pixel of this group is flagged; we have to look at the group on our left to see if this pixel starts the
				// edge or if it is part of an edge starting at some pixel on our left (we look at most 32 pixels to our left).
				// firstbitlow(~X) counts how many bits in X are set to 1, counting from the right (lowest order bit).
				// [The 0x80000000 is a "guard" for the case where left is all ones, to make sure firstbitlow returns 31 (firstbitlow(0) returns -1)]
				
				LeftBitsCount = firstbitlow( ~left | 0x80000000 );

				// Recompute the bitmask, using the LeftBitsCount lowest bits from "left" as high bits.
				// In other words, we will be scanning from LeftBitsCount pixels to the left of the currently processed pixel group.
				// i.e. if LeftBitCounts = 5, then NewMask[31:27] = left[4:0] and NewMask[26:0] = BgMaskU[31:5]
				// [We preshift left by 1 below because in HLSL (left << 32) is the same as (left << 0)]
				
				NewMask = ( (left << 1) << (31 - LeftBitsCount) ) | (BgMaskU >> LeftBitsCount);
			}
			else
			{	// edge begins within this group (bit 0 to 30). We shift the bitmask so that its highest bit corresponds to the start of the edge.
				// e.g. if from = 28, then NewMask[31:3] = BgMaskU[28:0] and NewMask[2:0] = right[31:29]
				NewMask = (BgMaskU << (31 - from)) | (right >> (from + 1));
			}

			// Find the bit in the new mask that corresponds to the first pixel after the end of the edge (edge starts at bit 31 by construction...)
			// From this we can then easily compute the edge's length...
			int AfterEdgeBit = firstbithigh( ~NewMask );
			uint EdgeLength = 31 - AfterEdgeBit;          // will be 32 if NewMask is all ones, as firstbithigh will assign -1 toAfterEdgeBit

			// Update BgMaskU so that all the high order bits down to the one after the edge are set to 0, so that we start scanning for an edge
			// at this bit on the next iteration of the loop, and we know we are done scanning when BgMaskU == 0.
			// "to" below is the index of the last bit of the edge in BgMaskU (not NewMask!!). Note that it is negative in the case where the edge 
			// spans over right; e.g. from = 28 and EdgeLength = 31 => to = -2 which corresponds to bit 30 of right.		
			int to = from - (EdgeLength - LeftBitsCount) + 1;
			uint ClampedTo = max(0, to);
			BgMaskU &= (0x7FFFFFFF >> (31 - ClampedTo));

			if(EdgeLength < MinimumEdgeLength)
			{	// This edge is too short so don't process it further, scan for next edge
				continue;
			}

			// Now we check if there are any horizontal discontinuities/edges connected to this one on the row up and/or row down this one.
			// This is a key difference between MLAA and SAA (MLAA identifies patterns by looking for vertical discontinuities there).
			// For example, in the "left-up" case, we look for this pattern (assuming from = 28 and EdgeLength = 5) :
			//   upLeft |  up 
			//       ..?|??1...            To check for this pattern, we build a new mask luMask where, in this example: 
			//          |000111110....     luMask[31:3] = upLeft[28:0] and luMask[2:0] = up[31:29]
			//    left  | BgMaskU          Then computing firstbitlow(~luMask) gives us the number of bits set to 1 in luMask, counting from the right
			//                             i.e. the length of the "left up edge" connected to this edge (4 here if all "?" are 1 in the diagram)
			// Generalizing this, the 4 possible neighboring edges' lengths are computed as:

			uint lu = firstbitlow( ~ ( (upLeft   >> LeftBitsCount) << (31 - from) | ((up   >> 1) >> from) ) );
			uint ld = firstbitlow( ~ ( (downLeft >> LeftBitsCount) << (31 - from) | ((down >> 1) >> from) ) );
			uint ru = 31 - firstbithigh( ~ ( ((up   << 1) << (31 - ClampedTo)) | ((upRight   << (ClampedTo - to)) >> ClampedTo) ) );
			uint rd = 31 - firstbithigh( ~ ( ((down << 1) << (31 - ClampedTo)) | ((downRight << (ClampedTo - to)) >> ClampedTo) ) );
			
			// Based on these values, we can assign the intercept points for our reconstructed edge equations...
			float yldec = 0.f;
			float ylinc = 0.f;
			float yrinc = 0.f;
			float yrdec = 0.f;
			[flatten] if( lu != 0  )
			{
				yldec = yinter;
			}
			[flatten] if( ld != 0  )
			{
				ylinc = -yinter;
			}
			[flatten] if( ru != 0 )
			{
				yrinc = yinter;
			}
			[flatten] if( rd != 0  )
			{
				yrdec = -yinter;
			}
			
			// ... then compute the equations parameters.
			float adec = (yrdec - yldec)/(float)(EdgeLength);
			float bdec = yldec;
			float ainc = (yrinc - ylinc)/(float)(EdgeLength);
			float binc = ylinc;

			for( uint i = 0; i <= from - ClampedTo; ++i )
			{
				float2 coord = float2( (RowCoords.x << 5) + (31 - from) + i, RowCoords.y );
				float weight =
						max( adec * (float)(i     + LeftBitsCount) + bdec, 0 ) + 
						max( adec * (float)(i + 1 + LeftBitsCount) + bdec, 0 ) + 
						max( ainc * (float)(i     + LeftBitsCount) + binc, 0 ) + 
						max( ainc * (float)(i + 1 + LeftBitsCount) + binc, 0 );
				weight *= 0.5f;
				float2 texCoord = float2( (coord.x + 0.5f) * InvColorBufferDims.x, (coord.y + weight + 0.5f) * InvColorBufferDims.y ); 
				Result[ coord.xy ] =  ColorBuffer.SampleLevel( LinearSampler, texCoord, 0 );
			}
		} // while(BgMaskU != 0)

		while(BgMaskD != 0)  // Same loop as above, except for the calculation of "coord" and "weight" in the inner for loop at the end
		{	
			uint from = firstbithigh( BgMaskD );
			uint NewMask = 0, LeftBitsCount = 0;

			if(from == 31)
			{
				LeftBitsCount = firstbitlow( ~left | 0x80000000 );
				NewMask = ( (left << 1) << (31 - LeftBitsCount) ) | (BgMaskD >> LeftBitsCount);
			}
			else
			{
				NewMask = (BgMaskD << (31 - from)) | (right >> (from + 1));
			}

			int AfterEdgeBit = firstbithigh( ~NewMask );
			uint EdgeLength = 31 - AfterEdgeBit; 		
			int to = from - (EdgeLength - LeftBitsCount) + 1;
			uint ClampedTo = max(0, to);
			BgMaskD &= (0x7FFFFFFF >> (31 - ClampedTo));

			if(EdgeLength < MinimumEdgeLength)
			{
				continue;
			}

			uint lu = firstbitlow( ~ ( (upLeft   >> LeftBitsCount) << (31 - from) | ((up   >> 1) >> from) ) );
			uint ld = firstbitlow( ~ ( (downLeft >> LeftBitsCount) << (31 - from) | ((down >> 1) >> from) ) );
			uint ru = 31 - firstbithigh( ~ ( ((up   << 1) << (31 - ClampedTo)) | ((upRight   << (ClampedTo - to)) >> ClampedTo) ) );
			uint rd = 31 - firstbithigh( ~ ( ((down << 1) << (31 - ClampedTo)) | ((downRight << (ClampedTo - to)) >> ClampedTo) ) );
			
			float yldec = 0.f;
			float ylinc = 0.f;
			float yrinc = 0.f;
			float yrdec = 0.f;
			[flatten] if( lu != 0  )
			{
				yldec = yinter;
			}
			[flatten] if( ld != 0  )
			{
				ylinc = -yinter;
			}
			[flatten] if( ru != 0 )
			{
				yrinc = yinter;
			}
			[flatten] if( rd != 0  )
			{
				yrdec = -yinter;
			}
			
			float adec = (yrdec - yldec)/(float)(EdgeLength);
			float bdec = yldec;
			float ainc = (yrinc - ylinc)/(float)(EdgeLength);
			float binc = ylinc;

			for( uint i = 0; i <= from - ClampedTo; ++i )
			{
				float2 coord = float2( (RowCoords.x << 5) + (31 - from) + i, RowCoords.y + 1 );  // +1 added to 2nd coord vs. previous loop
				float weight =   // Use mins instead of maxs in previous loop
						min( adec * (float)(i     + LeftBitsCount) + bdec, 0 ) + 
						min( adec * (float)(i + 1 + LeftBitsCount) + bdec, 0 ) + 
						min( ainc * (float)(i     + LeftBitsCount) + binc, 0 ) + 
						min( ainc * (float)(i + 1 + LeftBitsCount) + binc, 0 );
				weight *= 0.5f;
				float2 texCoord = float2( (coord.x + 0.5f) * InvColorBufferDims.x, (coord.y + weight + 0.5f) * InvColorBufferDims.y ); 
				Result[ coord.xy ] =  ColorBuffer.SampleLevel( LinearSampler, texCoord, 0 );
			}
		} // while(BgMaskD != 0)
	} // if(BgMask != 0)
}
