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

ByteAddressBuffer EdgeVBitArray : register( t0 );  // Stores presence/absence of horizontal edge, 1 bit/pixel
Texture2D ColorBuffer           : register( t1 );  // The input color buffer to post-process
RWTexture2D<float4> Result      : register( u0 );  // the output color buffer

SamplerState LinearSampler : register( s0 );


//-----------------------------------------------------------------------------------------------------
// Tweakables
//-----------------------------------------------------------------------------------------------------
#define xinter 0.5f                 // x intercept
#define MinimumEdgeLength    2      // If an edge's length is less than this, don't blend


//-----------------------------------------------------------------------------------------------------
// We are processing the color buffer in tiles of (32x32) pixels.
// Each thread processes a vertical group of 32 pixels.
// Each thread group has 32 such threads, so corresponds to the processing of a tile.
// Therefore the thread-related system values are automatically assigned thus:
// SV_GroupID = tile coordinates (e.g. (3,2,0) = 3rd tile from the top, 2nd tile from left)
// SV_DispatchThreadID = coordinates of the 32 pixels group of the color buffer we are processing
// (DTID.x in tiles and DTID.y in pixels as our thread group's size is (1,32,1))
// SV_GroupThreadID = which column in tile we are processing (e.g. (0,27,0) = tile's 28th column).
//-----------------------------------------------------------------------------------------------------

[numthreads(1,32,1)]
void CSMain( uint3 TileCoords      : SV_GroupID,
             uint3 ColCoords       : SV_DispatchThreadID)
{
	// This is the offset (in 32-bit = 4 bytes units) where the edge flags are stored in EdgeVBitArray for this column (32 pixels group)
	uint FlagsOffset     = ColCoords.x + ColCoords.y * ColorBufferTileCount.y;
	// Same for the column to the left...
	uint FlagsLeftOffset   = FlagsOffset - ColorBufferTileCount.y;
	// And the column to the right.
	uint FlagsRightOffset = FlagsOffset + ColorBufferTileCount.y;
	
	// We retrieve the edge flags for this column of 32 pixels, as well as the columns above and below it
	// (The << 2 converts the offset to byte units)
	uint3 current = EdgeVBitArray.Load3( (FlagsOffset - 1) << 2);
	uint BgMask = current.y;	// This is the edge bit mask for this column (Bg stands for "blending group")

	if(BgMask != 0)
	{	// There is at least one vertical discontinuity flagged in this group of 32 pixels...
		uint3 rightLine  = EdgeVBitArray.Load3( (FlagsRightOffset - 1)  << 2 );
		uint3 leftLine   = EdgeVBitArray.Load3( (FlagsLeftOffset -  1)  << 2 );
		
		uint up = current.x, down = current.z;
		uint rightUp = rightLine.x, right = rightLine.y, rightDown = rightLine.z;
		uint leftUp = leftLine.x, left = leftLine.y, leftDown = leftLine.z;

		uint BgMaskL = BgMask;// & (~left);
		uint BgMaskR = BgMask;// & (~right);

		while(BgMaskL != 0)
		{	// We are scanning for discontinuities top to bottom.
			// First we look for the highest set bit in the mask, which corresponds to the topmost pixel in the group with a vertical discontinuity.
			uint from = firstbithigh( BgMaskL );
			uint NewMask = 0, UpBitsCount = 0;

			if(from == 31)
			{	// The topmost pixel of this group is flagged; we have to look at the group above to see if this pixel starts the
				// edge or if it is part of an edge starting at some pixel above (we look at most 32 pixels above).
				// firstbitlow(~X) counts how many bits in X are set to 1, counting from the right (lowest order bit).
				// [The 0x80000000 is a "guard" for the case where up is all ones, to make sure firstbitlow returns 31 (firstbitlow(0) returns -1)]
				
				UpBitsCount = firstbitlow( ~up | 0x80000000 );

				// Recompute the bitmask, using the UpBitsCount lowest bits from "up" as high bits.
				// In other words, we will be scanning from UpBitsCount pixels above the currently processed pixel group.
				// i.e. if UpBitCounts = 5, then NewMask[31:27] = up[4:0] and NewMask[26:0] = BgMaskL[31:5]
				// [We preshift up by 1 below because in HLSL (up << 32) is the same as (up << 0)]
				
				NewMask = ( (up << 1) << (31 - UpBitsCount) ) | (BgMaskL >> UpBitsCount);
			}
			else
			{	// edge begins within this group (bit 0 to 30). We shift the bitmask so that its highest bit corresponds to the start of the edge.
				// e.g. if from = 28, then NewMask[31:3] = BgMaskL[28:0] and NewMask[2:0] = down[31:29]
				NewMask = (BgMaskL << (31 - from)) | (down >> (from + 1));
			}

			// Find the bit in the new mask that corresponds to the first pixel after the end of the edge (edge starts at bit 31 by construction...)
			// From this we can then easily compute the edge's length...
			int AfterEdgeBit = firstbithigh( ~NewMask );
			uint EdgeLength = 31 - AfterEdgeBit;          // will be 32 if NewMask is all ones, as firstbithigh will assign -1 toAfterEdgeBit

			// Update BgMaskL so that all the high order bits down to the one after the edge are set to 0, so that we start scanning for an edge
			// at this bit on the next iteration of the loop, and we know we are done scanning when BgMaskL == 0.
			// "to" below is the index of the last bit of the edge in BgMaskL (not NewMask!!). Note that it is negative in the case where the edge 
			// spans over down; e.g. from = 28 and EdgeLength = 31 => to = -2 which corresponds to bit 30 of down.		
			int to = from - (EdgeLength - UpBitsCount) + 1;
			uint ClampedTo = max(0, to);
			BgMaskL &= (0x7FFFFFFF >> (31 - ClampedTo));

			if(EdgeLength < MinimumEdgeLength)
			{	// This edge is too short so don't process it further, scan for next edge
				continue;
			}

			// Now we check if there are any vertical discontinuities/edges connected to this one on the column to the left and/or right of this one.
			// This is a key difference between MLAA and SAA (MLAA identifies patterns by looking for horizontal discontinuities there).
			// For example, for the horizontal pass, in the "left-up" case, we look for this pattern (assuming from = 28 and EdgeLength = 5) :
			//   upLeft |  up 
			//       ..?|??1...            To check for this pattern, we build a new mask luMask where, in this example: 
			//          |000111110....     luMask[31:3] = upLeft[28:0] and luMask[2:0] = up[31:29]
			//    left  | BgMaskU          Then computing firstbitlow(~luMask) gives us the number of bits set to 1 in luMask, counting from the right
			//                             i.e. the length of the "left up edge" connected to this edge (4 here if all "?" are 1 in the diagram)
			// Generalizing this, and transposing to the vertical pass, the 4 possible neighboring edges' lengths are computed as:

			uint lu = firstbitlow( ~ ( (leftUp  >> UpBitsCount) << (31 - from) | ((left  >> 1) >> from) ) );
			uint ru = firstbitlow( ~ ( (rightUp >> UpBitsCount) << (31 - from) | ((right >> 1) >> from) ) );
			uint ld = 31 - firstbithigh( ~ ( ((left  << 1) << (31 - ClampedTo)) | ((leftDown  << (ClampedTo - to)) >> ClampedTo) ) );
			uint rd = 31 - firstbithigh( ~ ( ((right << 1) << (31 - ClampedTo)) | ((rightDown << (ClampedTo - to)) >> ClampedTo) ) );
			
			// Based on these values, we can assign the intercept points for our reconstructed edge equations...
			float xudec = 0.f;
			float xuinc = 0.f;
			float xdinc = 0.f;
			float xddec = 0.f;
			[flatten] if( lu != 0  )
			{
				xudec = xinter;
			}
			[flatten] if( ru != 0  )
			{
				xuinc = -xinter;
			}
			[flatten] if( ld != 0 )
			{
				xdinc = xinter;
			}
			[flatten] if( rd != 0  )
			{
				xddec = -xinter;
			}
			
			// ... then compute the equations parameters.
			float adec = (xddec - xudec)/(float)(EdgeLength);
			float bdec = xudec;
			float ainc = (xdinc - xuinc)/(float)(EdgeLength);
			float binc = xuinc;

			for( uint i = 0; i <= from - ClampedTo; ++i )
			{
				float2 coord = float2( ColCoords.y, (ColCoords.x << 5) + (31 - from) + i );
				float weight =
						max( adec * (float)(i     + UpBitsCount) + bdec, 0 ) + 
						max( adec * (float)(i + 1 + UpBitsCount) + bdec, 0 ) + 
						max( ainc * (float)(i     + UpBitsCount) + binc, 0 ) + 
						max( ainc * (float)(i + 1 + UpBitsCount) + binc, 0 );
				weight *= 0.5f;
				float2 texCoord = float2( (coord.x + weight + 0.5f) * InvColorBufferDims.x, (coord.y + 0.5f) * InvColorBufferDims.y ); 
				Result[ coord.xy ] = ColorBuffer.SampleLevel( LinearSampler, texCoord, 0 );
			}
		} // while(BgMaskL != 0)

		while(BgMaskR != 0)  // Same loop as above, except for the calculation of "coord" and "weight" in the inner for loop at the end
		{	
			uint from = firstbithigh( BgMaskR );
			uint NewMask = 0, UpBitsCount = 0;

			if(from == 31)
			{
				UpBitsCount = firstbitlow( ~up | 0x80000000 );
				NewMask = ( (up << 1) << (31 - UpBitsCount) ) | (BgMaskR >> UpBitsCount);
			}
			else
			{
				NewMask = (BgMaskR << (31 - from)) | (down >> (from + 1));
			}

			int AfterEdgeBit = firstbithigh( ~NewMask );
			uint EdgeLength = 31 - AfterEdgeBit; 		
			int to = from - (EdgeLength - UpBitsCount) + 1;
			uint ClampedTo = max(0, to);
			BgMaskR &= (0x7FFFFFFF >> (31 - ClampedTo));

			if(EdgeLength < MinimumEdgeLength)
			{
				continue;
			}

			uint lu = firstbitlow( ~ ( (leftUp  >> UpBitsCount) << (31 - from) | ((left  >> 1) >> from) ) );
			uint ru = firstbitlow( ~ ( (rightUp >> UpBitsCount) << (31 - from) | ((right >> 1) >> from) ) );
			uint ld = 31 - firstbithigh( ~ ( ((left  << 1) << (31 - ClampedTo)) | ((leftDown  << (ClampedTo - to)) >> ClampedTo) ) );
			uint rd = 31 - firstbithigh( ~ ( ((right << 1) << (31 - ClampedTo)) | ((rightDown << (ClampedTo - to)) >> ClampedTo) ) );
			
			float xudec = 0.f;
			float xuinc = 0.f;
			float xdinc = 0.f;
			float xddec = 0.f;
			[flatten] if( lu != 0  )
			{
				xudec = xinter;
			}
			[flatten] if( ru != 0  )
			{
				xuinc = -xinter;
			}
			[flatten] if( ld != 0 )
			{
				xdinc = xinter;
			}
			[flatten] if( rd != 0  )
			{
				xddec = -xinter;
			}
			
			float adec = (xddec - xudec)/(float)(EdgeLength);
			float bdec = xudec;
			float ainc = (xdinc - xuinc)/(float)(EdgeLength);
			float binc = xuinc;

			for( uint i = 0; i <= from - ClampedTo; ++i )
			{
				float2 coord = float2( ColCoords.y + 1, (ColCoords.x << 5) + (31 - from) + i );  // +1 added to 1st coord vs. previous loop
				float weight =   // Use mins instead of maxs in previous loop
						min( adec * (float)(i     + UpBitsCount) + bdec, 0 ) + 
						min( adec * (float)(i + 1 + UpBitsCount) + bdec, 0 ) + 
						min( ainc * (float)(i     + UpBitsCount) + binc, 0 ) + 
						min( ainc * (float)(i + 1 + UpBitsCount) + binc, 0 );
				weight *= 0.5f;
				float2 texCoord = float2( (coord.x + weight + 0.5f) * InvColorBufferDims.x, (coord.y + 0.5f) * InvColorBufferDims.y ); 
				Result[ coord.xy ] =  ColorBuffer.SampleLevel( LinearSampler, texCoord, 0 );
			}
		} // while(BgMaskR != 0)
	} // if(BgMask != 0)
}

