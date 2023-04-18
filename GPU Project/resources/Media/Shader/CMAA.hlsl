// Copyright 2013 Intel Corporation
// All Rights Reserved
//
// Permission is granted to use, copy, distribute and prepare derivative works of this
// software for any purpose and without fee, provided, that the above copyright notice
// and this statement appear in all copies. Intel makes no representations about the
// suitability of this software for any purpose. THIS SOFTWARE IS PROVIDED "AS IS."
// INTEL SPECIFICALLY DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, AND ALL LIABILITY,
// INCLUDING CONSEQUENTIAL AND OTHER INDIRECT DAMAGES, FOR THE USE OF THIS SOFTWARE,
// INCLUDING LIABILITY FOR INFRINGEMENT OF ANY PROPRIETARY RIGHTS, AND INCLUDING THE
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  Intel does not
// assume any responsibility for any errors which may appear in this software nor any
// responsibility to update it.
//
// CMAA Version 1.3, by Filip Strugar (filip.strugar@intel.com)
//
/////////////////////////////////////////////////////////////////////////////////////////

static const float4 c_edgeDebugColours[5] = { float4( 0.5, 0.5, 0.5, 1 ), float4( 1, 0.1, 1.0, 1 ), float4( 0.9, 0, 0, 1 ), float4( 0, 0.9, 0, 1 ), float4( 0, 0, 0.9, 1 ) };

// Expecting values of 1 and 0 only!
uint PackEdge( uint4 edges )
{
   return dot( edges, uint4( 1, 2, 4, 8 ) );
}

// how .rgba channels from the edge texture maps to pixel edges:
//
//                   A - 0x08
//              |¯¯¯¯¯¯¯¯¯|
//              |         |
//     0x04 - B |  pixel  | R - 0x01
//              |         |
//              |_________|
//                   G - 0x02
//
// (A - there's an edge between us and a pixel above us)
// (R - there's an edge between us and a pixel to the right)
// (G - there's an edge between us and a pixel at the bottom)
// (B - there's an edge between us and a pixel to the left)

// some quality settings
#define SETTINGS_ALLOW_SHORT_Zs

// debugging
// #define DEBUG_DISABLE_SIMPLE_SHAPES // enable/disable simple shapes

uint4 UnpackEdge( uint value )
{
   uint4 ret;
   ret.x = (value & 0x01) != 0;
   ret.y = (value & 0x02) != 0;
   ret.z = (value & 0x04) != 0;
   ret.w = (value & 0x08) != 0;
   return ret;
}

uint PackZ( const uint2 screenPos, const bool invertedZShape )
{
   uint retVal = screenPos.x | (screenPos.y << 15);
   if( invertedZShape )
      retVal |= (1 << 30);
   return retVal;     
}

void UnpackZ( uint packedZ, out uint2 screenPos, out bool invertedZShape )
{
   screenPos.x = packedZ & 0x7FFF;
   screenPos.y = (packedZ>>15) & 0x7FFF;
   invertedZShape = (packedZ>>30) == 1;
}

uint PackZ( const uint2 screenPos, const bool invertedZShape, const bool horizontal )
{
   uint retVal = screenPos.x | (screenPos.y << 15);
   if( invertedZShape )
      retVal |= (1 << 30);
   if( horizontal )
      retVal |= (1 << 31);
   return retVal;     
}

void UnpackZ( uint packedZ, out uint2 screenPos, out bool invertedZShape, out bool horizontal )
{
   screenPos.x    = packedZ & 0x7FFF;
   screenPos.y    = (packedZ>>15) & 0x7FFF;
   invertedZShape = (packedZ & (1 << 30)) != 0;
   horizontal     = (packedZ & (1 << 31)) != 0; 
}
 
void UnpackBlurAAInfo( float packedValue, out uint edges, out uint shapeType )
{
    uint packedValueInt = (uint)(packedValue*255.5);
    edges       = packedValueInt & 0xF;
    shapeType   = packedValueInt >> 4;
}


#ifndef CMAA_INCLUDE_JUST_DEBUGGING_STUFF

// this isn't needed if colour UAV is _SRGB but that doesn't work everywhere
#ifdef IN_GAMMA_CORRECT_MODE

/////////////////////////////////////////////////////////////////////////////////////////
//
// SRGB Helper Functions taken from D3DX_DXGIFormatConvert.inl
float D3DX_FLOAT_to_SRGB(float val)
{ 
    if( val < 0.0031308f )
        val *= 12.92f;
    else
    {
        #ifdef _DEBUG
            val = abs( val );
        #endif
        val = 1.055f * pow(val,1.0f/2.4f) - 0.055f;
    }
    return val;
}
//
float3 D3DX_FLOAT3_to_SRGB(float3 val)
{
    float3 outVal;
    outVal.x = D3DX_FLOAT_to_SRGB( val.x );
    outVal.y = D3DX_FLOAT_to_SRGB( val.y );
    outVal.z = D3DX_FLOAT_to_SRGB( val.z );
    return outVal;
}
//
// SRGB_to_FLOAT_inexact is imprecise due to precision of pow implementations.
float D3DX_SRGB_to_FLOAT(float val)
{
    if( val < 0.04045f )
        val /= 12.92f;
    else
        val = pow((val + 0.055f)/1.055f,2.4f);
    return val;
}
//
float3 D3DX_SRGB_to_FLOAT3(float3 val)
{
    float3 outVal;
    outVal.x = D3DX_SRGB_to_FLOAT( val.x );
    outVal.y = D3DX_SRGB_to_FLOAT( val.y );
    outVal.z = D3DX_SRGB_to_FLOAT( val.z );
    return outVal;
}
//
float4 R8G8B8A8_UNORM_to_float4(uint packedInput)
{
    precise float4 unpackedOutput;
    unpackedOutput.r = (float)  (packedInput      & 0x000000ff)  / 255;
    unpackedOutput.g = (float)(((packedInput>> 8) & 0x000000ff)) / 255;
    unpackedOutput.b = (float)(((packedInput>>16) & 0x000000ff)) / 255;
    unpackedOutput.a = (float)(((packedInput>>24) & 0x000000ff)) / 255;
    return unpackedOutput;
}
uint float4_to_R8G8B8A8_UNORM(precise float4 unpackedInput)
{
    uint packedOutput;
    unpackedInput = min(max(unpackedInput,0),1); // NaN gets set to 0.
    unpackedInput *= 255;
    unpackedInput += 0.5f;
    unpackedInput = floor(unpackedInput);
    packedOutput = ( ((uint)unpackedInput.r)      |
                    (((uint)unpackedInput.g)<< 8) |
                    (((uint)unpackedInput.b)<<16) |
                    (((uint)unpackedInput.a)<<24) );
    return packedOutput;
}
//
/////////////////////////////////////////////////////////////////////////////////////////

#endif

// needed for one Gather call unfortunately :(
SamplerState PointSampler   : register( s0 ); // { Filter = MIN_MAG_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };

SamplerState LinearSampler  : register( s1 ); // { Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR; AddressU = Clamp; AddressV = Clamp; };

struct CMAAConstants
{
   float4   LumWeights;                         // .rgb - luminance weight for each colour channel; .w unused for now (maybe will be used for gamma correction before edge detect)

   float    ColorThreshold;                     // for simple edge detection
   float    DepthThreshold;                     // for depth (unused at the moment)
   float    NonDominantEdgeRemovalAmount;       // how much non-dominant edges to remove
   float    Dummy0;

   float2   OneOverScreenSize;
   int      ScreenWidth;
   int      ScreenHeight;

   float4   DebugZoomTool;
};

cbuffer CMAAGlobals : register(b4)
{
   CMAAConstants g_CMAA;
}

RWTexture2D<float>              g_resultTexture             : register( u0 );
RWTexture2D<float4>             g_resultTextureFlt4Slot1    : register( u1 );
RWTexture2D<float>              g_resultTextureSlot2        : register( u2 );

Texture2D<float4>               g_screenTexture	            : register( t0 );
Texture2D<float4>               g_depthTexture              : register( t1 );
Texture2D<uint4>                g_src0Texture4Uint          : register( t3 );
Texture2D<float>                g_src0TextureFlt		    : register( t3 );
Texture2D<float>                g_depthTextureFlt		    : register( t4 );
 
// Must be even number; Will work with ~16 pretty good too for additional performance, or with ~64 for highest quality.
static const uint c_maxLineLength   = 64;

float EdgeDetectColorCalcDiff( float3 colorA, float3 colorB )
{
#if 0
   // CONSIDER THIS as highest quality:
   // Weighted Euclidean distance
   // (Copyright © 2010, Thiadmer Riemersma, ITB CompuPhase, see http://www.compuphase.com/cmetric.htm for details)
   float rmean = ( colorA.r + colorB.r ) / 2.0;
   float3 delta = colorA - colorB;
   return sqrt( ( (2.0+rmean)*delta.r*delta.r ) + 4*delta.g*delta.g + ( (3.0-rmean)*delta.b*delta.b ) ) * 0.28;
   // (0.28 is an empirically set fudge to match two functions below)
#endif

// two versions, very similar results and almost identical performance
//   - maybe a bit higher quality per-color diff (use this by default)
//   - maybe a bit lower quality luma only diff (use this if luma already available in alpha channel)
#if 1
	float3 LumWeights   = g_CMAA.LumWeights.rgb;

	return dot( abs( colorA.rgb - colorB.rgb  ), LumWeights.rgb );
#else
    const float3 cLumaConsts = float3(0.299, 0.587, 0.114);                     // this matches FXAA (http://en.wikipedia.org/wiki/CCIR_601); above code uses http://en.wikipedia.org/wiki/Rec._709 
    return abs( dot( colorA, cLumaConsts ) - dot( colorB, cLumaConsts ) );
#endif
}

bool EdgeDetectColor( float3 colorA, float3 colorB )
{
     return EdgeDetectColorCalcDiff( colorA, colorB ) > g_CMAA.ColorThreshold;
}

float PackBlurAAInfo( uint2 pixelPos, uint shapeType )
{
    uint packedEdges = g_src0TextureFlt.Load( int3( pixelPos.xy, 0 ) ).r * 255.5;

    uint retval = packedEdges + (shapeType << 4);

    return float(retval) / 255.0;
}

void FindLineLength( out uint lineLengthLeft, out uint lineLengthRight, int2 screenPos, uniform bool horizontal, uniform bool invertedZShape, const int2 stepRight )
{

   /////////////////////////////////////////////////////////////////////////////////////////////////////////
   // TODO: there must be a cleaner and faster way to get to these - a precalculated array indexing maybe?
   uint maskLeft, bitsContinueLeft, maskRight, bitsContinueRight;
   {
      // Horizontal (vertical is the same, just rotated 90º counter-clockwise)
      // Inverted Z case:              // Normal Z case:
      //   __                          // __
      //  X|                           //  X|
      // ¯¯                            //   ¯¯
      uint maskTraceLeft, maskTraceRight;
      uint maskStopLeft, maskStopRight;
      if( horizontal )
      {
         if( invertedZShape )
         {
            maskTraceLeft    = 0x02; // tracing bottom edge
            maskTraceRight   = 0x08; // tracing top edge
         }
         else
         {
            maskTraceLeft    = 0x08; // tracing top edge
            maskTraceRight   = 0x02; // tracing bottom edge
         }
         maskStopLeft   = 0x01; // stop on right edge
         maskStopRight  = 0x04; // stop on left edge
      }
      else
      {
         if( invertedZShape )
         {
            maskTraceLeft    = 0x01; // tracing right edge
            maskTraceRight   = 0x04; // tracing left edge
         }
         else
         {
            maskTraceLeft    = 0x04; // tracing left edge
            maskTraceRight   = 0x01; // tracing right edge
         }
         maskStopLeft   = 0x08; // stop on top edge
         maskStopRight  = 0x02; // stop on bottom edge
      }

      maskLeft         = maskTraceLeft | maskStopLeft;
      bitsContinueLeft = maskTraceLeft;
      maskRight        = maskTraceRight | maskStopRight;
      bitsContinueRight= maskTraceRight;
   }
   /////////////////////////////////////////////////////////////////////////////////////////////////////////

   uint stopLimiter = c_maxLineLength*2;
#ifdef SETTINGS_ALLOW_SHORT_Zs
   uint i = 1;
#else
   uint i = 2; // starting from 2 because we already know it's at least 2...
#endif
   //[unroll]
   //[allow_uav_condition]
   [loop]
   for( ; i < c_maxLineLength; i++ )
   {
      uint edgeLeft  = g_src0TextureFlt.Load( int3( screenPos.xy - stepRight * i,       0 ) ).r * 255.5;
      uint edgeRight = g_src0TextureFlt.Load( int3( screenPos.xy + stepRight * (i+1),   0 ) ).r * 255.5;
      
      // stop on encountering 'stopping' edge (as defined by masks)
      //bool stopLeft  = ( (edgeLeft & maskStopLeft) != 0   ) || ( (edgeLeft & maskTraceLeft) == 0 );
      //bool stopRight = ( (edgeRight & maskStopRight) != 0 ) || ( (edgeRight & maskTraceRight) == 0 );
      bool stopLeft  = (edgeLeft & maskLeft) != bitsContinueLeft;
      bool stopRight = (edgeRight & maskRight) != bitsContinueRight;

      if( stopLeft || stopRight )
      {
         lineLengthLeft = 1 + i - stopLeft;
         lineLengthRight = 1 + i - stopRight;
         return;
      }
   }
   lineLengthLeft = lineLengthRight = i;
}

void ProcessDetectedZ( int2 screenPos, bool horizontal, bool invertedZShape )
{
   uint lineLengthLeft, lineLengthRight;

   const int2 stepRight     = (horizontal)?( int2( 1, 0 ) ):( int2( 0,  -1 ) );
   const float2 blendDir    = (horizontal)?( float2( 0, -1 ) ):( float2( -1,  0 ) );

   FindLineLength( lineLengthLeft, lineLengthRight, screenPos, horizontal, invertedZShape, stepRight );

   int width, height;
   g_screenTexture.GetDimensions( width, height );
   float2 pixelSize = float2( 1.0 / (float)width, 1.0 / (float)height );

   float leftOdd  = 0.15 * (lineLengthLeft % 2);
   float rightOdd = 0.15 * (lineLengthRight % 2);

   int loopFrom = -(int)((lineLengthLeft+1)/2)+1;
   int loopTo   = (int)((lineLengthRight+1)/2);

   float totalLength = (float)(loopTo - loopFrom)+1 - leftOdd - rightOdd;

   //[allow_uav_condition]
   [loop]
   for( int i = loopFrom; i <= loopTo; i++ )
   {
      int2      pixelPos    = screenPos + stepRight * i;
      float2    pixelPosFlt = float2( pixelPos.x + 0.5, pixelPos.y + 0.5 );

#ifdef DEBUG_OUTPUT_AAINFO
      g_resultTextureSlot2[ pixelPos ] = PackBlurAAInfo( pixelPos, 1 );
#endif

      // debug output a.)
      g_resultTextureFlt4Slot1[pixelPos] = float4( (i > 0)?(float3(1, 0, horizontal)):(float3(0, 1, horizontal)), 1.0 );

      // debug output b.)
      //g_resultTextureFlt4Slot1[pixelPos] = float4( float3( lineLengthLeft*10 / 255.0, lineLengthRight*10/255.0, horizontal ), 1.0 );
      //continue;

      float m = (i + 0.5 - leftOdd - loopFrom) / totalLength;
      m = saturate( m );
      float k = m - (i > 0);
      k = (invertedZShape)?(-k):(k);

      // debug output c.)
      // g_resultTextureFlt4Slot1[pixelPos] = float4( ( i > 0 )?( float3( 0.5-k, 0, horizontal ) ):( float3( 0, 0.5-k, horizontal ) ), 1.0 );

      float4 output = g_screenTexture.SampleLevel( LinearSampler, (pixelPosFlt + blendDir * k) * pixelSize, 0 );
      
#ifdef IN_GAMMA_CORRECT_MODE
      output.rgb = D3DX_FLOAT3_to_SRGB( output.rgb );
#endif

      g_resultTextureFlt4Slot1[pixelPos] = float4( output.rgba ); //, pixelC.a );
   }
}

float4 CalcDbgDisplayColor( const float4 blurMap )
{
   float3 pixelC = float3( 0.0, 0.0, 0.0 );
   float3 pixelL = float3( 0.0, 0.0, 1.0 );
   float3 pixelT = float3( 1.0, 0.0, 0.0 );
   float3 pixelR = float3( 0.0, 1.0, 0.0 );
   float3 pixelB = float3( 0.8, 0.8, 0.0 );

   const float centerWeight = 1.0;
   const float fromBelowWeight   = (1 / (1 - blurMap.x)) - 1;
   const float fromAboveWeight   = (1 / (1 - blurMap.y)) - 1;
   const float fromRightWeight   = (1 / (1 - blurMap.z)) - 1;
   const float fromLeftWeight    = (1 / (1 - blurMap.w)) - 1;

   const float weightSum = centerWeight + dot( float4( fromBelowWeight, fromAboveWeight, fromRightWeight, fromLeftWeight ), float4( 1, 1, 1, 1 ) );

   float4 pixel;

   //pixel = tex2D( g_xScreenTextureSampler, pixel_UV );
   pixel.rgb = pixelC.rgb + fromAboveWeight * pixelT + fromBelowWeight * pixelB + 
      fromLeftWeight * pixelL + fromRightWeight * pixelR;
   pixel.rgb /= weightSum;

   pixel.a = dot( pixel.rgb, float3( 1, 1, 1 ) ) * 100.0;

   //pixel.rgb = lerp( pixel.rgb, float3( 1, 0, 0 ), 0.5 );

   return saturate( pixel );
}


void Edges0PS( const float4 screenPos : SV_Position, out uint4 outEdges : SV_Target0, out float outDepth : SV_Depth )
{
    int3 screenPosI = int3( screenPos.xy, 0 ) * int3( 2, 2, 0 );

    // .rgb contains colour, .a contains flag whether to output it to working colour texture
    float4 pixel00   = float4( g_screenTexture.Load( screenPosI ).rgba                 );
    float4 pixel10   = float4( g_screenTexture.Load( screenPosI, uint2(  1, 0 ) ).rgba );
    float4 pixel20   = float4( g_screenTexture.Load( screenPosI, uint2(  2, 0 ) ).rgba );
    float4 pixel01   = float4( g_screenTexture.Load( screenPosI, uint2( 0,  1 ) ).rgba );
    float4 pixel11   = float4( g_screenTexture.Load( screenPosI, uint2( 1,  1 ) ).rgba );
    float4 pixel21   = float4( g_screenTexture.Load( screenPosI, uint2( 2,  1 ) ).rgba );
    float4 pixel02   = float4( g_screenTexture.Load( screenPosI, uint2( 0,  2 ) ).rgba );
    float4 pixel12   = float4( g_screenTexture.Load( screenPosI, uint2( 1,  2 ) ).rgba );

    float storeFlagPixel00 = 0;
    float storeFlagPixel10 = 0;
    float storeFlagPixel20 = 0;
    float storeFlagPixel01 = 0;
    float storeFlagPixel11 = 0;
    float storeFlagPixel21 = 0;
    float storeFlagPixel02 = 0;
    float storeFlagPixel12 = 0;

    float2 et;

    {
        et.x = EdgeDetectColorCalcDiff( pixel00.rgb, pixel10.rgb );
        et.y = EdgeDetectColorCalcDiff( pixel00.rgb, pixel01.rgb );
        et = saturate( et - g_CMAA.ColorThreshold.xx );
        int2 eti = int2( et * 15 + 0.99 );
        outEdges.x = eti.x | (eti.y << 4);

        storeFlagPixel00 += et.x;
        storeFlagPixel00 += et.y;
        storeFlagPixel10 += et.x;
        storeFlagPixel01 += et.y;
    }

    {
        et.x = EdgeDetectColorCalcDiff( pixel10.rgb, pixel20.rgb );
        et.y = EdgeDetectColorCalcDiff( pixel10.rgb, pixel11.rgb );
        et = saturate( et - g_CMAA.ColorThreshold.xx );
        int2 eti = int2( et * 15 + 0.99 );
        outEdges.y = eti.x | (eti.y << 4);

        storeFlagPixel10 += et.x;
        storeFlagPixel10 += et.y;
        storeFlagPixel20 += et.x;
        storeFlagPixel11 += et.y;
    }

    {
        et.x = EdgeDetectColorCalcDiff( pixel01.rgb, pixel11.rgb );
        et.y = EdgeDetectColorCalcDiff( pixel01.rgb, pixel02.rgb );
        et = saturate( et - g_CMAA.ColorThreshold.xx );
        int2 eti = int2( et * 15 + 0.99 );
        outEdges.z = eti.x | (eti.y << 4);

        storeFlagPixel01 += et.x;
        storeFlagPixel01 += et.y;
        storeFlagPixel11 += et.x;
        storeFlagPixel02 += et.y;
    }

    {
        et.x = EdgeDetectColorCalcDiff( pixel11.rgb, pixel21.rgb );
        et.y = EdgeDetectColorCalcDiff( pixel11.rgb, pixel12.rgb );
        et = saturate( et - g_CMAA.ColorThreshold.xx );
        int2 eti = int2( et * 15 + 0.99 );
        outEdges.w = eti.x | (eti.y << 4);

        storeFlagPixel11 += et.x;
        storeFlagPixel11 += et.y;
        storeFlagPixel21 += et.x;
        storeFlagPixel12 += et.y;
    }

    outDepth = (any(outEdges) != 0)?(1.0):(0.0);

    if( outDepth != 0 )
    {
        if( storeFlagPixel00 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 0, 0 ) ] = pixel00.rgba;
        if( storeFlagPixel10 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 1, 0 ) ] = pixel10.rgba;
        if( storeFlagPixel20 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 2, 0 ) ] = pixel20.rgba;
        if( storeFlagPixel01 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 0, 1 ) ] = pixel01.rgba;
        if( storeFlagPixel02 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 0, 2 ) ] = pixel02.rgba;
        if( storeFlagPixel11 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 1, 1 ) ] = pixel11.rgba;
        if( storeFlagPixel21 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 2, 1 ) ] = pixel21.rgba;
        if( storeFlagPixel12 != 0 ) 
            g_resultTextureFlt4Slot1[ screenPosI.xy + int2( 1, 2 ) ] = pixel12.rgba;
    }
}

float2 UnpackThresholds( uint val )
{
    return float2( val & 0x0F, val >> 4 ) / 15.0f;
}

uint PruneNonDominantEdges( float4 edges[3] )
{
    float4 maxE4    = float4( 0.0, 0.0, 0.0, 0.0 );

    float avg = 0.0;

    [unroll]
    for( int i = 0; i < 3; i++ )
    {
        maxE4 = max( maxE4, edges[i] );

        avg = dot( edges[i], float4( 1, 1, 1, 1 ) / ( 3.0 * 4.0 ) );
    }

    float2 maxE2    = max( maxE4.xy, maxE4.zw );
    float maxE      = max( maxE2.x, maxE2.y );

    float threshold = avg * (1.0 - g_CMAA.NonDominantEdgeRemovalAmount) + maxE * (g_CMAA.NonDominantEdgeRemovalAmount);

//    threshold = 0.0001; // this disables non-dominant edge pruning!
            
    bool cx = edges[0].x >= threshold;
    bool cy = edges[0].y >= threshold;

    return PackEdge( uint4( cx, cy, 0, 0 ) );
}

void CollectEdges( int offX, int offY, out float4 edges[3], const uint packedVals[6][6] )
{
    float2 pixelP0P0 = UnpackThresholds( packedVals[offX][offY] );    
    float2 pixelP1P0 = UnpackThresholds( packedVals[offX+1][offY] );  
    float2 pixelP0P1 = UnpackThresholds( packedVals[offX][offY+1] );  
    float2 pixelM1P0 = UnpackThresholds( packedVals[offX-1][offY] );  
    float2 pixelP0M1 = UnpackThresholds( packedVals[offX][offY-1] );  
    float2 pixelP1M1 = UnpackThresholds( packedVals[offX+1][offY-1] );
    float2 pixelM1P1 = UnpackThresholds( packedVals[offX-1][offY+1] );

    edges[ 0].x = pixelP0P0.x;
    edges[ 0].y = pixelP0P0.y;
    edges[ 0].z = pixelP1P0.x;
    edges[ 0].w = pixelP1P0.y;
    edges[ 1].x = pixelP0P1.x;
    edges[ 1].y = pixelP0P1.y;
    edges[ 1].z = pixelM1P0.x;
    edges[ 1].w = pixelM1P0.y;
    edges[ 2].x = pixelP0M1.x;
    edges[ 2].y = pixelP0M1.y;
    edges[ 2].z = pixelP1M1.y;
    edges[ 2].w = pixelM1P1.x;
}

[earlydepthstencil]
void Edges1PS( const float4 _screenPos : SV_Position )
{
    uint2 screenPosI = (uint2)_screenPos;

    // source : edge differences from previous pass
    uint packedVals[6][6];

    // center pixel (our output)
    uint4 packedQ4 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2(  0,   0 ) ).rgba;
    packedVals[2][2] = packedQ4.x;
    packedVals[3][2] = packedQ4.y;
    packedVals[2][3] = packedQ4.z;
    packedVals[3][3] = packedQ4.w;

    // unused
    // packedVals[0][0] = 0; //packedQ0.x;
    // packedVals[1][0] = 0; //packedQ0.y;
    // packedVals[0][1] = 0; //packedQ0.z;
    // packedVals[1][1] = 0; //packedQ0.w;

    // unused
    //packedVals[4][4] = 0; //packedQ8.x;
    //packedVals[5][4] = 0; //packedQ8.y;
    //packedVals[4][5] = 0; //packedQ8.z;
    //packedVals[5][5] = 0; //packedQ8.w;

    float4 edges[3];
    uint pe;

    if( packedVals[2][2] || packedVals[3][2] )
    {
        uint4 packedQ1 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2(  0,  -1 ) ).rgba;
        packedVals[2][0] = packedQ1.x;
        packedVals[3][0] = packedQ1.y;
        packedVals[2][1] = packedQ1.z;
        packedVals[3][1] = packedQ1.w;
    }

    if( packedVals[2][2] || packedVals[2][3] )
    {
        uint4 packedQ3 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2( -1,   0 ) ).rgba;
        packedVals[0][2] = packedQ3.x;
        packedVals[1][2] = packedQ3.y;
        packedVals[0][3] = packedQ3.z;
        packedVals[1][3] = packedQ3.w;
    }
    
    if( packedVals[2][2] )
    {
        CollectEdges( 2, 2, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
            g_resultTexture[ int2( screenPosI.x*2+0, screenPosI.y*2+0 ) ] = (pe | 0x80) / 255.0;
    }

    if( packedVals[3][2] || packedVals[3][3] )
    {
        uint4 packedQ5 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2(  1,   0 ) ).rgba;
        packedVals[4][2] = packedQ5.x;
        packedVals[5][2] = packedQ5.y;
        packedVals[4][3] = packedQ5.z;
        packedVals[5][3] = packedQ5.w;
    }

    if( packedVals[3][2] )
    {
        uint4 packedQ2 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2(  1,  -1 ) ).rgba;
        packedVals[4][0] = packedQ2.x;
        packedVals[5][0] = packedQ2.y;
        packedVals[4][1] = packedQ2.z;
        packedVals[5][1] = packedQ2.w;

        CollectEdges( 3, 2, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
            g_resultTexture[ int2( screenPosI.x*2+1, screenPosI.y*2+0 ) ] = (pe | 0x80) / 255.0;
    }

    if( packedVals[2][3] || packedVals[3][3] )
    {
        uint4 packedQ7 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2(  0,   1 ) ).rgba;
        packedVals[2][4] = packedQ7.x;
        packedVals[3][4] = packedQ7.y;
        packedVals[2][5] = packedQ7.z;
        packedVals[3][5] = packedQ7.w;
    }

    if( packedVals[2][3] )
    {
        uint4 packedQ6 = g_src0Texture4Uint.Load( int3( screenPosI.xy, 0 ), uint2( -1,   1 ) ).rgba;
        packedVals[0][4] = packedQ6.x;
        packedVals[1][4] = packedQ6.y;
        packedVals[0][5] = packedQ6.z;
        packedVals[1][5] = packedQ6.w;

        CollectEdges( 2, 3, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
            g_resultTexture[ int2( screenPosI.x*2+0, screenPosI.y*2+1 ) ] = (pe | 0x80) / 255.0;
    }

    if( packedVals[3][3] )
    {
        CollectEdges( 3, 3, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
            g_resultTexture[ int2( screenPosI.x*2+1, screenPosI.y*2+1 ) ] = (pe | 0x80) / 255.0;
    }
}


void EdgesCombinePS( const float4 _screenPos : SV_Position, out float outDepth : SV_Depth )
{
    outDepth = 0.0;

    const int3 screenPosIBase = int3( ((int2)_screenPos) * 2, 0 );

    uint packedEdgesArray[3][3];

    // use only if it has the 'prev frame' flag: do "sample * 255.0 - 127.5" -> if it has the last bit flag (128), it's going to stay above 0
    uint4 sampA = (uint4)(g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 1, 0 ) ) * 255.0 - 127.5);
    uint4 sampB = (uint4)(g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 0, 1 ) ) * 255.0 - 127.5);
    uint  sampC = (uint)(g_src0TextureFlt.Load( screenPosIBase.xyz, int2( 1, 1 ) ) * 255.0 - 127.5);
    packedEdgesArray[0][0] = 0.0;
    packedEdgesArray[1][0] = sampA.w;
    packedEdgesArray[2][0] = sampA.z;
    packedEdgesArray[1][1] = sampA.x;
    packedEdgesArray[2][1] = sampA.y;
    packedEdgesArray[0][1] = sampB.w;
    packedEdgesArray[0][2] = sampB.x;
    packedEdgesArray[1][2] = sampB.y;
    packedEdgesArray[2][2] = sampC;

    uint4 pixelsC = uint4( packedEdgesArray[1+0][1+0], packedEdgesArray[1+1][1+0], packedEdgesArray[1+0][1+1], packedEdgesArray[1+1][1+1] );
    uint4 pixelsL = uint4( packedEdgesArray[0+0][1+0], packedEdgesArray[0+1][1+0], packedEdgesArray[0+0][1+1], packedEdgesArray[0+1][1+1] );
    uint4 pixelsU = uint4( packedEdgesArray[1+0][0+0], packedEdgesArray[1+1][0+0], packedEdgesArray[1+0][0+1], packedEdgesArray[1+1][0+1] );

    uint4 outEdge4 = pixelsC | ((pixelsL & 0x01) << 2) | ((pixelsU & 0x02) << 2);
    float4 outEdge4Flt = outEdge4 / 255.0;

    g_resultTextureSlot2[ screenPosIBase.xy + int2( 0, 0 ) ] = outEdge4Flt.x;
    g_resultTextureSlot2[ screenPosIBase.xy + int2( 1, 0 ) ] = outEdge4Flt.y;
    g_resultTextureSlot2[ screenPosIBase.xy + int2( 0, 1 ) ] = outEdge4Flt.z;
    g_resultTextureSlot2[ screenPosIBase.xy + int2( 1, 1 ) ] = outEdge4Flt.w;

    int4 numberOfEdges4 = countbits( outEdge4 );

    outDepth = any( numberOfEdges4 > 1 );

    // magic depth codepath
    //outDepth = dot( numberOfEdges4 > 1, float4( 1.0/2.0, 1.0/4.0, 1.0/8.0, 1.0/16.0 ) );
}

[earlydepthstencil]
void ProcessAndApplyPS( const float4 _screenPos : SV_Position )
{
    uint _i;

    const int3 screenPosIBase = int3( ((int2)_screenPos) * 2, 0 );

    //float magicDepth = g_depthTextureFlt.Load( int3( (int2)_screenPos.xy, 0 ) );

    uint forFollowUpCount = 0;
    int4 forFollowUpCoords[4];

    uint packedEdgesArray[4][4];

    uint4 sampA = g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 0, 0 ) ) * 255.5;
    uint4 sampB = g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 2, 0 ) ) * 255.5;
    uint4 sampC = g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 0, 2 ) ) * 255.5;
    uint4 sampD = g_src0TextureFlt.GatherRed( PointSampler, screenPosIBase.xy * g_CMAA.OneOverScreenSize, int2( 2, 2 ) ) * 255.5;
    packedEdgesArray[0][0] = sampA.w;
    packedEdgesArray[1][0] = sampA.z;
    packedEdgesArray[0][1] = sampA.x;
    packedEdgesArray[1][1] = sampA.y;
    packedEdgesArray[2][0] = sampB.w;
    packedEdgesArray[3][0] = sampB.z;
    packedEdgesArray[2][1] = sampB.x;
    packedEdgesArray[3][1] = sampB.y;
    packedEdgesArray[0][2] = sampC.w;
    packedEdgesArray[1][2] = sampC.z;
    packedEdgesArray[0][3] = sampC.x;
    packedEdgesArray[1][3] = sampC.y;
    packedEdgesArray[2][2] = sampD.w;
    packedEdgesArray[3][2] = sampD.z;
    packedEdgesArray[2][3] = sampD.x;
    packedEdgesArray[3][3] = sampD.y;

    [unroll]
    for( _i = 0; _i < 4; _i++ )
    {
        int _x = _i%2;
        int _y = _i/2;

        //magicDepth *= 2.0;        
        //if( magicDepth < 0.99 )
        //    continue;
        //magicDepth -= 1.0;

        const int3 screenPosI = screenPosIBase + int3( _x, _y, 0 );

        //#ifdef IN_GAMMA_CORRECT_MODE
        //        g_resultTextureFlt4Slot1[ screenPosI.xy ] = float4( D3DX_FLOAT3_to_SRGB( float3( 1, 0, 0 ) ), 1 );
        //#else
        //        g_resultTextureFlt4Slot1[ screenPosI.xy ] = float4( float3( 0, 1, 0 ), 1 );
        //#endif
        //        continue;


        const uint packedEdgesC = packedEdgesArray[1+_x][1+_y]; // packedEdgesC4[_i]; // g_src0Texture.Load( screenPosI ).r;

        // int numberOfEdges = countbits( packedEdgesC );

        const uint4 edges       = UnpackEdge( packedEdgesC );
        const float4 edgesFlt   = (float4)edges;

        float numberOfEdges = dot( edgesFlt, float4( 1, 1, 1, 1 ) );

        if( numberOfEdges < 2 )
            continue;

        const float fromRight   = edgesFlt.r;
        const float fromBelow   = edgesFlt.g;
        const float fromLeft    = edgesFlt.b;
        const float fromAbove   = edgesFlt.a;

        float4 xFroms = float4( fromBelow, fromAbove, fromRight, fromLeft );

        //this is number of edges - we already have this
        //float fSum = dot( xFroms, float4( 1, 1, 1, 1 ) );

        float blurCoeff = 0.0;

        // These are additional blurs that complement the main line-based blurring;
        // Unlike line-based, these do not necessarily preserve the total amount of screen colour as they will
        // take neighbouring pixel colours and apply them to the one currently processed.

#ifndef DEBUG_DISABLE_SIMPLE_SHAPES // enable/disable simple shapes
        // 1.) L-like shape.
        // For this shape, the total amount of screen colour will be preserved when this is a part 
        // of a (zigzag) diagonal line as the corners from the other side will do the same and
        // take some of the current pixel's colour in return.
        // However, in the case when this is an actual corner, the pixel's colour will be partially
        // overwritten by it's 2 neighbours.
        // if( numberOfEdges > 1 )
        {
       
            // with value of 0.15, the pixel will retain approx 77% of its colour and the remaining 23% will 
            // come from its 2 neighbours (which are likely to be blurred too in the opposite direction)
            blurCoeff = 0.08;

            // Only do blending if it's L shape - if we're between two parallel edges, don't do anything
            blurCoeff *= (1 - fromBelow * fromAbove) * (1 - fromRight * fromLeft);
        }
    
        // 2.) U-like shape (surrounded with edges from 3 sides)
        [flatten]
        if( numberOfEdges > 2 )
        {
            // with value of 0.13, the pixel will retain approx 72% of its colour and the remaining 28% will 
            // be picked from its 3 neighbours (which are unlikely to be blurred too but could be)
            blurCoeff = 0.11;
        }

        // 3.) Completely surrounded with edges from all 4 sides
        [flatten]
        if( numberOfEdges > 3 )
        {
            // with value of 0.07, the pixel will retain 78% of its colour and the remaining 22% will 
            // come from its 4 neighbours (which are unlikely to be blurred)
            blurCoeff = 0.05;
        }

        if( blurCoeff == 0 )
        {
            // this avoids Z search below as well but that's ok because a Z shape will also always have
            // some blurCoeff
            continue;
        }
#endif // DEBUG_DISABLE_SIMPLE_SHAPES

        float4 blurMap = xFroms * blurCoeff;

        float4 pixelC = g_screenTexture.Load( screenPosI, int2( 0,  0 ) ).rgba;

        const float centerWeight = 1.0;
        const float fromBelowWeight = blurMap.x; // (1 / (1 - blurMap.x)) - 1; // this would be the proper math for blending if we were handling
        const float fromAboveWeight = blurMap.y; // (1 / (1 - blurMap.y)) - 1; // lines (Zs) and mini kernel smoothing here, but since we're doing
        const float fromRightWeight = blurMap.z; // (1 / (1 - blurMap.z)) - 1; // lines separately, no need to complicate, just tweak the settings.
        const float fromLeftWeight  = blurMap.w; // (1 / (1 - blurMap.w)) - 1;

        const float fourWeightSum   = dot( blurMap, float4( 1, 1, 1, 1 ) );
        const float allWeightSum    = centerWeight + fourWeightSum;

        float4 output = float4( 0, 0, 0, 0 );
        [flatten]
        if( fromLeftWeight > 0.0 )
        {
            float3 pixelL = g_screenTexture.Load( screenPosI, int2( -1,  0 ) ).rgb;
            output.rgb += fromLeftWeight * pixelL;
        }
        [flatten]
        if( fromAboveWeight > 0.0 )
        {
            float3 pixelT = g_screenTexture.Load( screenPosI, int2(  0, -1 ) ).rgb;
            output.rgb += fromAboveWeight * pixelT;
        }
        [flatten]
        if( fromRightWeight > 0.0 )
        {
            float3 pixelR = g_screenTexture.Load( screenPosI, int2(  1,  0 ) ).rgb;
            output.rgb += fromRightWeight * pixelR;
        }
        [flatten]
        if( fromBelowWeight > 0.0 )
        {   
            float3 pixelB = g_screenTexture.Load( screenPosI, int2(  0,  1 ) ).rgb;
            output.rgb += fromBelowWeight * pixelB;
        }

        output /= fourWeightSum + 0.0001;
        output.a = 1 - centerWeight / allWeightSum;

        output.rgb = lerp( pixelC.rgb, output.rgb, output.a ).rgb;
#ifdef IN_GAMMA_CORRECT_MODE
        output.rgb = D3DX_FLOAT3_to_SRGB( output.rgb );
#endif

#ifdef DEBUG_OUTPUT_AAINFO
    #ifndef DEBUG_DISABLE_SIMPLE_SHAPES // enable/disable simple shapes
        g_resultTextureSlot2[ screenPosI.xy ] = PackBlurAAInfo( screenPosI.xy, numberOfEdges );
    #endif
#endif

        g_resultTextureFlt4Slot1[ screenPosI.xy ] = float4( output.rgb, pixelC.a );

        if( numberOfEdges == 2 )
        {

            uint packedEdgesL    = packedEdgesArray[0+_x][1+_y];
            uint packedEdgesT    = packedEdgesArray[1+_x][0+_y];
            uint packedEdgesR    = packedEdgesArray[2+_x][1+_y];
            uint packedEdgesB    = packedEdgesArray[1+_x][2+_y];

            //bool isNotHorizontal = 
            bool isHorizontalA = ( ( packedEdgesC ) == (0x01 | 0x02) ) && ( (packedEdgesR & (0x01 | 0x08) ) == (0x08) );
            bool isHorizontalB = ( ( packedEdgesC ) == (0x01 | 0x08) ) && ( (packedEdgesR & (0x01 | 0x02) ) == (0x02) );

            bool isHCandidate = isHorizontalA || isHorizontalB;

            bool isVerticalA = ( ( packedEdgesC ) == (0x08 | 0x01) ) && ( (packedEdgesT & (0x08 | 0x04) ) == (0x04) );
            bool isVerticalB = ( ( packedEdgesC ) == (0x08 | 0x04) ) && ( (packedEdgesT & (0x08 | 0x01) ) == (0x01) );
            bool isVCandidate = isVerticalA || isVerticalB;

            bool isCandidate = isHCandidate || isVCandidate;

            if( !isCandidate )
                continue;

            bool horizontal = isHCandidate;

            // what if both are candidates? do additional pruning (still not 100% but gets rid of worst case errors)
            if( isHCandidate && isVCandidate )
                horizontal = ( isHorizontalA && ( ( packedEdgesL & 0x02 ) == 0x02 ) ) || ( isHorizontalB && ( ( packedEdgesL & 0x08 ) == 0x08 ) );

            int2 offsetC;
            uint packedEdgesM1P0;
            uint packedEdgesP1P0;
            if( horizontal )
            {
                packedEdgesM1P0 = packedEdgesL;
                packedEdgesP1P0 = packedEdgesR;
                offsetC = int2(  2,  0 );
            }
            else
            {
                packedEdgesM1P0 = packedEdgesB;
                packedEdgesP1P0 = packedEdgesT;
                offsetC = int2(  0, -2 );
            }

            //uint4 edges        = UnpackEdge( packedEdgesC );
            uint4 edgesM1P0    = UnpackEdge( packedEdgesM1P0 );
            uint4 edgesP1P0    = UnpackEdge( packedEdgesP1P0 );
            uint4 edgesP2P0    = UnpackEdge( g_src0TextureFlt.Load( int3( screenPosI.xy + offsetC, 0 ) ).r * 255.5 );

            uint4 arg0;
            uint4 arg1;
            uint4 arg2;
            uint4 arg3;
            bool arg4;

            if( horizontal )
            {
                arg0 = edges;
                arg1 = edgesM1P0;
                arg2 = edgesP1P0;
                arg3 = edgesP2P0;
                arg4 = true;
            }
            else
            {
                // Reuse the same code for vertical (used for horizontal above), but rotate input data 90º counter-clockwise, so that:
                // left     becomes     bottom
                // top      becomes     left
                // right    becomes     top
                // bottom   becomes     right

                // we also have to rotate edges, thus .argb
                arg0 = edges.argb;
                arg1 = edgesM1P0.argb;
                arg2 = edgesP1P0.argb;
                arg3 = edgesP2P0.argb;
                arg4 = false;
            }

            //DetectZsHorizontal( screenPosI.xy, arg0, arg1, arg2, arg3, arg4 );
            {
                const int2 screenPos = screenPosI.xy;
                const uint4 _edges = arg0;
                const uint4 _edgesM1P0 = arg1;
                const uint4 _edgesP1P0 = arg2;
                const uint4 _edgesP2P0 = arg3;
                bool horizontal = arg4;
                // Inverted Z case:
                //   __
                //  X|
                // ¯¯
                bool isInvertedZ = false;
                bool isNormalZ = false;
                {
#ifndef SETTINGS_ALLOW_SHORT_Zs
                    uint isZShape		= _edges.r * _edges.g * _edgesM1P0.g * _edgesP1P0.a * _edgesP2P0.a * (1-_edges.b) * (1-_edgesP1P0.r) * (1-_edges.a) * (1-_edgesP1P0.g);   // (1-_edges.a) constraint can be removed; it was added for some rare cases
#else
                    uint isZShape		= _edges.r * _edges.g *                _edgesP1P0.a *                (1-_edges.b) * (1-_edgesP1P0.r) * (1-_edges.a) * (1-_edgesP1P0.g);   // (1-_edges.a) constraint can be removed; it was added for some rare cases
                    isZShape           *= ( _edgesM1P0.g + _edgesP2P0.a ); // and at least one of these need to be there
#endif

                    if( isZShape > 0.0 )
                    {
                        isInvertedZ = true;
                    }
                }

                // Normal Z case:
                // __
                //  X|
                //   ¯¯
                {
#ifndef SETTINGS_ALLOW_SHORT_Zs
                    uint isZShape   = _edges.r * _edges.a * _edgesM1P0.a * _edgesP1P0.g * _edgesP2P0.g * (1-_edges.b) * (1-_edgesP1P0.r) * (1-_edges.g) * (1-_edgesP1P0.a);   // (1-_edges.g) constraint can be removed; it was added for some rare cases
#else
                    uint isZShape     = _edges.r * _edges.a *                _edgesP1P0.g                * (1-_edges.b) * (1-_edgesP1P0.r) * (1-_edges.g) * (1-_edgesP1P0.a);   // (1-_edges.g) constraint can be removed; it was added for some rare cases
                    isZShape         *= ( _edgesM1P0.a + _edgesP2P0.g ); // and at least one of these need to be there
#endif

                    if( isZShape > 0.0 )
                    {
                        isNormalZ = true;
                    }
                }
                bool isZ = isInvertedZ || isNormalZ;
                [branch]
                if( isZ )
                {
                    forFollowUpCoords[forFollowUpCount++] = int4( screenPosI.xy, horizontal, isInvertedZ );
                }
            }
        }
    }

    // This code below is the only potential bug with this algorithm : it HAS to be executed after the simple shapes above. It used to be executed as a separate compute 
    // shader (by storing the packed 'forFollowUpCoords' in an append buffer and consuming it later) but the whole thing (append/consume buffers, using CS) appears to 
    // be too inefficient on most hardware.
    // However, it seems to execute fairly efficiently here and without any issues, although there is no 100% guarantee that this code below will execute across all pixels 
    // (it has a c_maxLineLength wide kernel) after other shaders processing same pixels have done solving simple shapes. It appears to work regardless, across all 
    // hardware; pixels with 1-edge or two opposing edges are ignored by simple shapes anyway and other shapes stop the long line algorithm from executing; the only danger
    // appears to be simple shape L's colliding with Z shapes from neighbouring pixels but I couldn't reproduce any problems on any hardware.
    [loop]
    for( _i = 0; _i < forFollowUpCount; _i++ )
    {
        int4 data = forFollowUpCoords[_i];
        ProcessDetectedZ( data.xy, data.z, data.w );
    }
}

[earlydepthstencil]
float4 DbgDisplayEdgesPS( const float4 screenPos : SV_Position ) : SV_Target
{
    float4 output = float4( 0, 0, 0, 0 );

    uint packedEdges, shapeType;
    UnpackBlurAAInfo( g_src0TextureFlt.Load( int3( screenPos.xy, 0 ) ).r, packedEdges, shapeType );
    float4 edges = (float4)UnpackEdge( packedEdges );

    bool showShapes = true;

    if( !showShapes )
    {
        float alpha = saturate( dot( edges, float4( 1, 1, 1, 1 ) ) * 255.5f );

        edges.rgb *= 0.8;
        edges.rgb += edges.aaa * float3( 15 / 255.0, 31 / 255.0, 63 / 255.0 );

        output = float4( edges.rgb, alpha );
    }
    else
    {
        if( any( edges.xyzw > 0 ) )
        {
            output = c_edgeDebugColours[shapeType];
            output.a = 0.8;
            if( shapeType == 0 )
                output.a = 0.4;
        }
    }
    
    return output;
}

bool IsInRect( float2 pt, float4 rect )
{
    return ( (pt.x >= rect.x) && (pt.x <= rect.z) && (pt.y >= rect.y) && (pt.y <= rect.w) );
}

void DistToClosestRectEdge( float2 pt, float4 rect, out float dist, out int edge )
{
    edge = 0;
    dist = 1e20;

    float distTmp;
    distTmp = abs( pt.x - rect.x );
    if( distTmp <= dist ) { dist = distTmp; edge = 2; }  // left

    distTmp = abs( pt.y - rect.y );
    if( distTmp <= dist ) { dist = distTmp; edge = 3; }  // top

    distTmp = abs( pt.x - rect.z ); 
    if( distTmp <= dist ) { dist = distTmp; edge = 0; }  // right

    distTmp = abs( pt.y - rect.w );
    if( distTmp <= dist ) { dist = distTmp; edge = 1; }  // bottom
}

void DistToClosestRectEdge( float2 pt, float4 rect, out float dist, out int edge, int ignoreEdge )
{
    edge = 0;
    dist = 1e20;

    float distTmp;
    if( ignoreEdge != 2 )
    {
        distTmp = abs( pt.x - rect.x );
        if( distTmp <= dist ) { dist = distTmp; edge = 2; }  // left
    }

    if( ignoreEdge != 3 )
    {
        distTmp = abs( pt.y - rect.y );
        if( distTmp <= dist ) { dist = distTmp; edge = 3; }  // top
    }

    if( ignoreEdge != 0 )
    {
        distTmp = abs( pt.x - rect.z ); 
        if( distTmp <= dist ) { dist = distTmp; edge = 0; }  // right
    }

    if( ignoreEdge != 1 )
    {
        distTmp = abs( pt.y - rect.w );
        if( distTmp <= dist ) { dist = distTmp; edge = 1; }  // bottom
    }
}

float2 RectToRect( float2 pt, float2 srcRCentre, float2 srcRSize, float2 dstRCentre, float2 dstRSize )
{
    pt -= srcRCentre;
    pt /= srcRSize;

    pt *= dstRSize;
    pt += dstRCentre;
    
    return pt;
}

float4 DbgDisplayZoomBoxPS( const float4 screenPos : SV_Position ) : SV_Target
{
    float4 srcRect = g_CMAA.DebugZoomTool;
    bool showEdges = false;
    if( srcRect.x > srcRect.z )
    {
        srcRect = -srcRect;
        showEdges = true;
    }

    if( IsInRect(screenPos.xy, srcRect ) )
    {
        // draw source box frame
        float dist; int edge;
        DistToClosestRectEdge( screenPos.xy, srcRect, dist, edge );

        return float4( 0.8, 1, 0.8, dist < 1.1 );
    }

    float zoomFactor = 10;

    const float2 screenSize = float2(g_CMAA.ScreenWidth, g_CMAA.ScreenHeight);
    const float2 screenCenter = float2(g_CMAA.ScreenWidth, g_CMAA.ScreenHeight) * 0.5;

    float2 srcRectSize = float2( srcRect.z - srcRect.x, srcRect.w - srcRect.y );
    float2 srcRectCenter = srcRect.xy + srcRectSize.xy * 0.5;

    float2 displayRectSize = srcRectSize * zoomFactor.xx;
    float2 displayRectCenter; 
    displayRectCenter.x = (srcRectCenter.x > screenCenter.x)?(srcRectCenter.x - srcRectSize.x * 0.5 - displayRectSize.x * 0.5 - 350):(srcRectCenter.x + srcRectSize.x * 0.5 + displayRectSize.x * 0.5 + 350);
    
    //displayRectCenter.y = (srcRectCenter.y > screenCenter.y)?(srcRectCenter.y - srcRectSize.y * 0.5 - displayRectSize.y * 0.5 - 50):(srcRectCenter.y + srcRectSize.y * 0.5 + displayRectSize.y * 0.5 + 50);
    displayRectCenter.y = lerp( displayRectSize.y/2, screenSize.y - displayRectSize.y/2, srcRectCenter.y / screenSize.y );
    
    float4 displayRect = float4( displayRectCenter.xy - displayRectSize.xy * 0.5, displayRectCenter.xy + displayRectSize.xy * 0.5 );

    bool chessPattern = (((uint)screenPos.x + (uint)screenPos.y) % 2) == 0;

    if( IsInRect(screenPos.xy, displayRect ) )
    {
        {
            // draw destination box frame
            float dist; int edge;
            DistToClosestRectEdge( screenPos.xy, displayRect, dist, edge );

            if( dist < 1.1 )
                return float4( 1.0, 0.8, 0.8, dist < 1.1 );
        }

        float2 texCoord = RectToRect( screenPos.xy, displayRectCenter, displayRectSize, srcRectCenter, srcRectSize );

        float3 colour = g_screenTexture.Load( int3( texCoord, 0 ) ).rgb;

        if( showEdges )
        {
            float4 thisPixRect, thisPixRectBig4;
            thisPixRect.xy = RectToRect( screenPos.xy, displayRectCenter, displayRectSize, srcRectCenter, srcRectSize );
            thisPixRect.zw = RectToRect( screenPos.xy, displayRectCenter, displayRectSize, srcRectCenter, srcRectSize );
            thisPixRect.xy = RectToRect( floor( thisPixRect.xy ), srcRectCenter, srcRectSize, displayRectCenter, displayRectSize );
            thisPixRect.zw = RectToRect( ceil(  thisPixRect.zw ), srcRectCenter, srcRectSize, displayRectCenter, displayRectSize );

            float dist; int edge;
            DistToClosestRectEdge( screenPos.xy, thisPixRect, dist, edge );
            if( dist < 1.1 ) //&& chessPattern )
            {
                uint packedEdges, shapeType;
                UnpackBlurAAInfo( g_src0TextureFlt.Load( int3( texCoord.xy, 0 ) ).r, packedEdges, shapeType );
                float4 edges = (float4)UnpackEdge( packedEdges );

                float4 edgeColour = c_edgeDebugColours[shapeType];

                if( shapeType == 0 )
                    edgeColour = float4( lerp( colour.rgb, edgeColour.rgb, 0.8), 1 );

                //edgeColour = float4( 0, 1, 1, 1 );

                if( edges[edge] != 0 )
                    return edgeColour;

                // fill in a small corner gap
                DistToClosestRectEdge( screenPos.xy, thisPixRect, dist, edge, edge );
                if( ( dist < 1.1 ) && (edges[edge] != 0) )
                    return edgeColour;
            }
        }

        return float4( colour, 1 );
    }


    return float4( 0.0, 0.5, 0, 0.0 );
}

#endif // #ifndef CMAA_INCLUDE_JUST_DEBUGGING_STUFF