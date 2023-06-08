#version 330 core


// The pragma below is critical for optimal performance
// in this fragment shader to let the shader compiler
// fully optimize the maths and batch the texture fetches
// optimally
#ifndef GL_ES
//#pragma optionNV(unroll all)
/*
#pragma optionNV(fastmath on)
#pragma optionNV(fastprecision on)
#pragma optionNV(inline all)
#pragma optionNV(ifcvt none)
#pragma optionNV(strict on)*/
#endif

#define float2 vec2
#define bool4 bvec4

#define float3 vec3
#define float4 vec4
#define bool2 bvec2
#define bool3 bvec3
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4
#define matrix   mat4
#define float4x3 mat4x3

#define half2 vec2
#define half3 vec3
#define half4 vec4

#define uint2 uvec2
#define uint3 uvec3
#define uint4 uvec4

#define int2 ivec2
#define int3 ivec3
#define int4 ivec4

#define lerp(x,y,v) mix(x,y,v)
#define rcp(x) 1.0/x
#define saturate(x) clamp(x, 0.0, 1.0)
#define frac(x) fract(x)
#define rsqrt(x) inversesqrt(x)
#define InterlockedOr(x, y) atomicOr(x, y)
#define firstbithigh(x) findMSB(x)
#define firstbitlow(x)  findLSB(x)
#define atan2(y,x)  atan(y,x)
#define reversebits(x) bitfieldReverse(x)
#define countbits(x)   bitCount(x)
#define asuint(x) floatBitsToUint(x)
#define ddx(x)    dFdx(x)
#define ddy(x)    dFdy(x)

// #define mul(M, V) M * V

#define isfinite(x) !(isnan(x) || isinf(x))

#ifndef GroupMemoryBarrierWithGroupSync
#define GroupMemoryBarrierWithGroupSync barrier
#endif
#define groupshared shared

#define GroupMemoryBarrier memoryBarrier

vec4 mul(in vec4 v, in mat4 m )
{
	return m * v;
}

vec3 mul(in vec3 v, in mat3 m )
{
	return m * v;
}

vec4 mul(in mat4 m , in vec4 v)
{
	return m * v;
}

vec3 mul(in mat3 m , in vec3 v)
{
	return m * v;
}

vec2 mul(in mat2 m , in vec2 v)
{
	return m * v;
}

void sincos(float angle, out float _sin, out float _cos)
{
    _sin = sin(angle);
    _cos = cos(angle);
}

void sincos(float2 angle, out float2 _sin, out float2 _cos)
{
    _sin = sin(angle);
    _cos = cos(angle);
}

float asfloat(uint i)
{
    return uintBitsToFloat(i);
}

float asfloat(int i)
{
    return intBitsToFloat(i);
}

float f16tof32( in uint value)
{
    return unpackHalf2x16(value).x;
}

float2 f16tof32( in uint2 value)
{
    return float2(unpackHalf2x16(value.x).x, unpackHalf2x16(value.y).x);
}

float3 f16tof32( in uint3 value)
{
    return float3(unpackHalf2x16(value.x).x, unpackHalf2x16(value.y).x, unpackHalf2x16(value.z).x);
}

float4 f16tof32( in uint4 value)
{
    return float4(unpackHalf2x16(value.x).x, unpackHalf2x16(value.y).x, unpackHalf2x16(value.z).x, unpackHalf2x16(value.w).x);
}

uint f32tof16(in float value)
{
    return packHalf2x16(vec2(value, 0));
}

uint2 f32tof16(in vec2 value)
{
    return uint2(packHalf2x16(vec2(value.x, 0)), packHalf2x16(vec2(value.y, 0)));
}

uint3 f32tof16(in float3 value)
{
    return uint3(packHalf2x16(vec2(value.x, 0)), packHalf2x16(vec2(value.y, 0)), packHalf2x16(vec2(value.z, 0)));
}


uint4 f32tof16(in float4 value)
{
    return uint4(packHalf2x16(vec2(value.x, 0)), packHalf2x16(vec2(value.y, 0)), packHalf2x16(vec2(value.z, 0)), packHalf2x16(vec2(value.w, 0)));
}

#define SV_ThreadGroupSize gl_WorkGroupSize
#define SV_NumThreadGroup  gl_NumWorkGroups
#define SV_GroupID         gl_WorkGroupID
#define SV_GroupThreadID   gl_LocalInvocationID
#define SV_DispatchThreadID gl_GlobalInvocationID
#define SV_GroupIndex      gl_LocalInvocationIndex

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

const float4 c_edgeDebugColours[5] = {
    float4(0.5, 0.5, 0.5, 1),
    float4(1, 0.1, 1.0, 1),
    float4(0.9, 0, 0, 1),
    float4(0, 0.9, 0, 1),
    float4(0, 0, 0.9, 1)
};

// Expecting values of 1 and 0 only!
uint PackEdge(uint4 edges)
{
    uint result = edges.x + edges.y * 2u + edges.z * 4u + edges.w * 8u;
    return result;
}

// how .rgba channels from the edge texture maps to pixel edges:
//
//                   A - 0x08
//              |瘄
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

uint4 UnpackEdge(uint value)
{
   uint4 ret;
   ret.x = uint((value & 0x01u) != 0u);
   ret.y = uint((value & 0x02u) != 0u);
   ret.z = uint((value & 0x04u) != 0u);
   ret.w = uint((value & 0x08u) != 0u);
   return ret;
}

uint PackZ( const uint2 screenPos, const bool invertedZShape )
{
   uint retVal = screenPos.x | (screenPos.y << 15);
   if( invertedZShape )
      retVal |= uint(1 << 30);
   return retVal;
}

void UnpackZ( uint packedZ, out uint2 screenPos, out bool invertedZShape )
{
   screenPos.x = packedZ & 0x7FFFu;
   screenPos.y = (packedZ>>15) & 0x7FFFu;
   invertedZShape = (packedZ>>30) == 1u;
}

uint PackZ( const uint2 screenPos, const bool invertedZShape, const bool horizontal )
{
   uint retVal = screenPos.x | (screenPos.y << 15);
   if( invertedZShape )
      retVal |= uint(1 << 30);
   if( horizontal )
      retVal |= uint(1 << 31);
   return retVal;
}

void UnpackZ( uint packedZ, out uint2 screenPos, out bool invertedZShape, out bool horizontal )
{
   screenPos.x    = packedZ & 0x7FFFu;
   screenPos.y    = (packedZ>>15) & 0x7FFFu;
   invertedZShape = (packedZ & uint(1 << 30)) != 0u;
   horizontal     = (packedZ & uint(1 << 31)) != 0u;
}

void UnpackBlurAAInfo( float packedValue, out uint edges, out uint shapeType )
{
    uint packedValueInt = uint(packedValue*255.5);
    edges       = packedValueInt & 0xFu;
    shapeType   = packedValueInt >> 4;
}


//#ifndef CMAA_INCLUDE_JUST_DEBUGGING_STUFF

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

#if 0

#define R8G8B8A8_UNORM_to_float4(x) unpackUnorm4x8(x)
#define float4_to_R8G8B8A8_UNORM(x) packUnorm4x8(x)

#else
float4 R8G8B8A8_UNORM_to_float4(uint packedInput)
{
    /*precise*/ float4 unpackedOutput;
    unpackedOutput.r = float  (packedInput      & 0x000000ffu) / 255.0;
    unpackedOutput.g = float ((packedInput>> 8) & 0x000000ffu) / 255.0;
    unpackedOutput.b = float ((packedInput>>16) & 0x000000ffu) / 255.0;
    unpackedOutput.a = float ((packedInput>>24) & 0x000000ffu) / 255.0;
    return unpackedOutput;
}
uint float4_to_R8G8B8A8_UNORM(/*precise*/ float4 unpackedInput)
{
    uint packedOutput;
    unpackedInput = min(max(unpackedInput,0),1); // NaN gets set to 0.
    unpackedInput *= 255.0;
    unpackedInput += 0.5f;
    unpackedInput = floor(unpackedInput);
    packedOutput = ( (uint(unpackedInput.r))      |
                    ((uint(unpackedInput.g)<< 8)) |
                    ((uint(unpackedInput.b)<<16)) |
                    ((uint(unpackedInput.a)<<24)) );
    return packedOutput;
}
#endif
//
/////////////////////////////////////////////////////////////////////////////////////////

#endif

// needed for one Gather call unfortunately :(
//SamplerState PointSampler   : register( s0 ); // { Filter = MIN_MAG_MIP_POINT; AddressU = Clamp; AddressV = Clamp; };
//SamplerState LinearSampler  : register( s1 ); // { Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR; AddressU = Clamp; AddressV = Clamp; };

struct CMAAConstants
{
   float4   LumWeights;                         // .rgb - luminance weight for each colour channel; .w unused for now (maybe will be used for gamma correction before edge detect)

   float    ColorThreshold;                     // for simple edge detection
   float    DepthThreshold;                     // for depth (unused at the moment)
   float    NonDominantEdgeRemovalAmount;       // how much non-dominant edges to remove
   float    Dummy0;

   float2   OneOverScreenSize;
   float    ScreenWidth;
   float    ScreenHeight;

   float4   DebugZoomTool;
};

#if 0
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

#else
layout(std140) uniform CMAAGlobals
{
    CMAAConstants g_CMAA;
};

uniform sampler2D g_resultTexture;
uniform sampler2D g_resultTextureFlt4Slot1;
uniform sampler2D g_resultTextureSlot2;

uniform sampler2D g_screenTexture;
uniform sampler2D g_depthTexture;
uniform usampler2D g_src0Texture4Uint;
uniform sampler2D g_src0TextureFlt;
uniform sampler2D g_depthTextureFlt;

#endif



// Must be even number; Will work with ~16 pretty good too for additional performance, or with ~64 for highest quality.
/*static*/ const uint c_maxLineLength   = 64;

float EdgeDetectColorCalcDiff( float3 colorA, float3 colorB )
{
#if 0
   // CONSIDER THIS as highest quality:
   // Weighted Euclidean distance
   // (Copyright ?2010, Thiadmer Riemersma, ITB CompuPhase, see http://www.compuphase.com/cmetric.htm for details)
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
    uint packedEdges = uint(texelFetch(g_src0TextureFlt, int2(pixelPos.xy), 0 ).r * 255.5);

    uint retval = packedEdges + (shapeType << 4);

    return float(retval) / 255.0;
}

void FindLineLength( out uint lineLengthLeft, out uint lineLengthRight, int2 screenPos,
                /*uniform*/ bool horizontal, /*uniform*/ bool invertedZShape, const int2 stepRight )
{

   /////////////////////////////////////////////////////////////////////////////////////////////////////////
   // TODO: there must be a cleaner and faster way to get to these - a precalculated array indexing maybe?
   uint maskLeft, bitsContinueLeft, maskRight, bitsContinueRight;
   {
      // Horizontal (vertical is the same, just rotated 90?counter-clockwise)
      // Inverted Z case:              // Normal Z case:
      //   __                          // __
      //  X|                           //  X|
      //                               //
      uint maskTraceLeft, maskTraceRight;
        uint maskStopLeft, maskStopRight;
        if (horizontal)
        {
            if (invertedZShape)
            {
                maskTraceLeft = 0x02u; // tracing bottom edge
                maskTraceRight = 0x08u; // tracing top edge
            }
            else
            {
                maskTraceLeft = 0x08u; // tracing top edge
                maskTraceRight = 0x02u; // tracing bottom edge
            }
            maskStopLeft = 0x01u; // stop on right edge
            maskStopRight = 0x04u; // stop on left edge
        }
        else
        {
            if (invertedZShape)
            {
                maskTraceLeft = 0x01u; // tracing right edge
                maskTraceRight = 0x04u; // tracing left edge
            }
            else
            {
                maskTraceLeft = 0x04u; // tracing left edge
                maskTraceRight = 0x00u; // tracing right edge
            }
            maskStopLeft = 0x08u; // stop on top edge
            maskStopRight = 0x02u; // stop on bottom edge
        }

        maskLeft = maskTraceLeft | maskStopLeft;
        bitsContinueLeft = maskTraceLeft;
        maskRight = maskTraceRight | maskStopRight;
        bitsContinueRight = maskTraceRight;
    }
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    uint stopLimiter = c_maxLineLength * 2u;
#ifdef SETTINGS_ALLOW_SHORT_Zs
    uint i = 1u;
#else
    uint i = 2u; // starting from 2 because we already know it's at least 2...
#endif
    for (; i < c_maxLineLength; i++)
    {
        vec2 offsetRight = stepRight * float(i);
        vec4 texColorLeft = texture(g_src0TextureFlt, screenPos - offsetRight);
        vec4 texColorRight = texture(g_src0TextureFlt, screenPos + stepRight * float(i + 1.0));

        uint edgeLeft = uint(texColorLeft.r * 255.5);
        uint edgeRight = uint(texColorRight.r * 255.5);

        // stop on encountering 'stopping' edge (as defined by masks)
        bool stopLeft = (edgeLeft & maskLeft) != bitsContinueLeft;
        bool stopRight = (edgeRight & maskRight) != bitsContinueRight;

        if (stopLeft || stopRight)
        {
            lineLengthLeft = 1u + i - uint(stopLeft ? 1u : 0u);
            lineLengthRight = 1u + i - uint(stopRight ? 1u : 0u);
            return;
        }
    }
    lineLengthLeft = lineLengthRight = i;
}

void ProcessDetectedZ( int2 screenPos, bool horizontal, bool invertedZShape )
{
   uint lineLengthLeft, lineLengthRight;

   int2 stepRight = (horizontal) ? int2(1, 0) : int2(0, -1);
   float2 blendDir = (horizontal) ? float2(0, -1) : float2(-1, 0);

   FindLineLength( lineLengthLeft, lineLengthRight, screenPos, horizontal, invertedZShape, stepRight );

   int width, height;
//   g_screenTexture.GetDimensions( width, height );
   int2 tex_size = textureSize(g_screenTexture, 0);
   width = tex_size.x;
   height = tex_size.y;
   float2 pixelSize = float2( 1.0 / float(width), 1.0 / float(height) );

   float leftOdd  = 0.15 * float(lineLengthLeft % 2u);
   float rightOdd = 0.15 * float(lineLengthRight % 2u);

   int loopFrom = -int((lineLengthLeft + 1u) / 2u) + 1;
   int loopTo = int((lineLengthRight + 1u) / 2u);

   float totalLength = float(uint(loopTo - loopFrom)) + 1.0 - leftOdd - rightOdd;


   //[allow_uav_condition]
//   [loop]
   for( int i = loopFrom; i <= loopTo; i++ )
   {
      int2      pixelPos    = screenPos + stepRight * i;
      float2    pixelPosFlt = float2( pixelPos.x + 0.5, pixelPos.y + 0.5 );

#ifdef DEBUG_OUTPUT_AAINFO
//      g_resultTextureSlot2[ pixelPos ] = PackBlurAAInfo( pixelPos, 1 );
      gl_FragColor = vec4(PackBlurAAInfo(pixelPos, 1));
#endif

      // debug output a.)
//      g_resultTextureFlt4Slot1[pixelPos] = float4( (i > 0)?(float3(1, 0, horizontal)):(float3(0, 1, horizontal)), 1.0 );
        gl_FragColor = vec4((i > 0) ? vec3(1, 0, horizontal) : vec3(0, 1, horizontal), 1.0);

      // debug output b.)
      //g_resultTextureFlt4Slot1[pixelPos] = float4( float3( lineLengthLeft*10 / 255.0, lineLengthRight*10/255.0, horizontal ), 1.0 );
      //continue;

      float m = (i + 0.5 - leftOdd - loopFrom) / totalLength;
      m = saturate( m );
      float k = m - float(i > 0);
      k = (invertedZShape)?(-k):(k);

      // debug output c.)
      // g_resultTextureFlt4Slot1[pixelPos] = float4( ( i > 0 )?( float3( 0.5-k, 0, horizontal ) ):( float3( 0, 0.5-k, horizontal ) ), 1.0 );

      float4 _output = textureLod( g_screenTexture, (pixelPosFlt + blendDir * k) * pixelSize, 0.0 );  //LinearSampler

#ifdef IN_GAMMA_CORRECT_MODE
      _output.rgb = D3DX_FLOAT3_to_SRGB( _output.rgb );
#endif

//      g_resultTextureFlt4Slot1[pixelPos] = float4( _output.rgba ); //, pixelC.a );
        gl_FragColor = vec4(_output.rgb, 1.0);
   }
}

float4 CalcDbgDisplayColor( const float4 blurMap )
{
   vec3 pixelC = vec3(0.0, 0.0, 0.0);
   vec3 pixelL = vec3(0.0, 0.0, 1.0);
   vec3 pixelT = vec3(1.0, 0.0, 0.0);
   vec3 pixelR = vec3(0.0, 1.0, 0.0);
   vec3 pixelB = vec3(0.8, 0.8, 0.0);

   float centerWeight = 1.0;
   float fromBelowWeight = (1.0 / (1.0 - blurMap.x)) - 1.0;
   float fromAboveWeight = (1.0 / (1.0 - blurMap.y)) - 1.0;
   float fromRightWeight = (1.0 / (1.0 - blurMap.z)) - 1.0;
   float fromLeftWeight = (1.0 / (1.0 - blurMap.w)) - 1.0;

   float weightSum = centerWeight + fromBelowWeight + fromAboveWeight + fromRightWeight + fromLeftWeight;

   vec4 pixel;

   //pixel = tex2D( g_xScreenTextureSampler, pixel_UV );
   pixel.rgb = pixelC.rgb + fromAboveWeight * pixelT + fromBelowWeight * pixelB +
      fromLeftWeight * pixelL + fromRightWeight * pixelR;
   pixel.rgb /= weightSum;

   pixel.a = dot( pixel.rgb, float3( 1, 1, 1 ) ) * 100.0;

   //pixel.rgb = lerp( pixel.rgb, float3( 1, 0, 0 ), 0.5 );

   return saturate( pixel );
}
}


layout(location = 0) out uint4 outEdges;

float2 UnpackThresholds( uint val )
{
    return float2( val & 0x0Fu, val >> 4 ) / 15.0f;
}

uint PruneNonDominantEdges( float4 edges[3] )
{
    float4 maxE4    = float4( 0.0, 0.0, 0.0, 0.0 );

    float avg = 0.0;

//    [unroll]
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

layout(early_fragment_tests) in;

void main()
{
    int2 screenPosI = int2(gl_FragCoord.xy);

    // source : edge differences from previous pass
    uint packedVals[6][6];

    // center pixel (our output)
    uint4 packedQ4 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2(  0,   0 ) ).rgba;
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

    if( packedVals[2][2]!=0 || packedVals[3][2]!=0 )
    {
        uint4 packedQ1 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2(  0,  -1 ) ).rgba;
        packedVals[2][0] = packedQ1.x;
        packedVals[3][0] = packedQ1.y;
        packedVals[2][1] = packedQ1.z;
        packedVals[3][1] = packedQ1.w;
    }

    if( packedVals[2][2]!=0 || packedVals[2][3]!=0 )
    {
        uint4 packedQ3 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2( -1,   0 ) ).rgba;
        packedVals[0][2] = packedQ3.x;
        packedVals[1][2] = packedQ3.y;
        packedVals[0][3] = packedQ3.z;
        packedVals[1][3] = packedQ3.w;
    }

    if( packedVals[2][2]!=0  )
    {
        CollectEdges( 2, 2, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
//            g_resultTexture[ int2( screenPosI.x*2+0, screenPosI.y*2+0 ) ] = (pe | 0x80) / 255.0;
            imageStore(g_resultTexture, int2( screenPosI.x*2+0, screenPosI.y*2+0 ), float4(pe | 0x80u) / 255.0);
    }

    if( packedVals[3][2]!=0  || packedVals[3][3]!=0  )
    {
        uint4 packedQ5 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2(  1,   0 ) ).rgba;
        packedVals[4][2] = packedQ5.x;
        packedVals[5][2] = packedQ5.y;
        packedVals[4][3] = packedQ5.z;
        packedVals[5][3] = packedQ5.w;
    }

    if( packedVals[3][2]!=0  )
    {
        uint4 packedQ2 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2(  1,  -1 ) ).rgba;
        packedVals[4][0] = packedQ2.x;
        packedVals[5][0] = packedQ2.y;
        packedVals[4][1] = packedQ2.z;
        packedVals[5][1] = packedQ2.w;

        CollectEdges( 3, 2, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
//            g_resultTexture[ int2( screenPosI.x*2+1, screenPosI.y*2+0 ) ] = (pe | 0x80u) / 255.0;
            imageStore(g_resultTexture, int2( screenPosI.x*2+1, screenPosI.y*2+0 ), float4(pe | 0x80u) / 255.0);
    }

    if( packedVals[2][3]!=0  || packedVals[3][3]!=0  )
    {
        uint4 packedQ7 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2(  0,   1 ) ).rgba;
        packedVals[2][4] = packedQ7.x;
        packedVals[3][4] = packedQ7.y;
        packedVals[2][5] = packedQ7.z;
        packedVals[3][5] = packedQ7.w;
    }

    if( packedVals[2][3]!=0  )
    {
        uint4 packedQ6 = texelFetchOffset(g_src0Texture4Uint, screenPosI.xy, 0, int2( -1,   1 ) ).rgba;
        packedVals[0][4] = packedQ6.x;
        packedVals[1][4] = packedQ6.y;
        packedVals[0][5] = packedQ6.z;
        packedVals[1][5] = packedQ6.w;

        CollectEdges( 2, 3, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
//            g_resultTexture[ int2( screenPosI.x*2+0, screenPosI.y*2+1 ) ] = (pe | 0x80u) / 255.0;
            imageStore(g_resultTexture, int2( screenPosI.x*2+0, screenPosI.y*2+1 ), float4(pe | 0x80u) / 255.0);
    }

    if( packedVals[3][3]!=0  )
    {
        CollectEdges( 3, 3, edges, packedVals );
        uint pe = PruneNonDominantEdges( edges );
        if( pe != 0 )
//            g_resultTexture[ int2( screenPosI.x*2+1, screenPosI.y*2+1 ) ] = (pe | 0x80u) / 255.0;
            imageStore(g_resultTexture, int2( screenPosI.x*2+1, screenPosI.y*2+1 ), float4(pe | 0x80u) / 255.0);
    }
}